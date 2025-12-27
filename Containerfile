# Immich Server for FreeBSD
# Main application server (Node.js)

ARG BASE_VERSION=15
ARG IMMICH_VERSION=v2.4.1

FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

ARG IMMICH_VERSION

# Build dependencies (including C++ compiler and headers for native modules)
# FreeBSD base dev packages needed for pkg-config: openssl, zlib, xz (lzma), bzip2
RUN pkg update && pkg install -y \
    node22 npm-node22 \
    git-lite gmake pkgconf \
    FreeBSD-clang FreeBSD-clibs-dev \
    FreeBSD-openssl-dev FreeBSD-zlib-dev FreeBSD-xz-dev FreeBSD-bzip2-dev \
    python311 \
    vips \
    ffmpeg \
    p5-Image-ExifTool \
    libheif \
    libraw \
    webp \
    && pkg clean -ay

# Set up compiler symlinks for node-gyp
RUN ln -sf /usr/bin/clang++ /usr/bin/c++ && \
    ln -sf /usr/bin/clang /usr/bin/cc

# Enable corepack for pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Clone immich source
WORKDIR /build
RUN git clone --depth 1 --branch ${IMMICH_VERSION} \
    https://github.com/immich-app/immich.git .

# Build server
WORKDIR /build/server

# Patch sharp to recognize UHDR loader (libvips 8.18+)
# TODO: Remove this patch once sharp adds UHDR support upstream
# See: https://github.com/lovell/sharp/issues - file an issue
# Problem: libvips 8.18 added UHDR support, but sharp's hardcoded loader map
# in common.cc doesn't include VipsForeignLoadUhdr*, causing "unsupported image
# format" errors for Ultra HDR images from Pixel phones.
RUN pnpm install --frozen-lockfile && \
    SHARP_DIR=$(find /build/node_modules/.pnpm -name 'sharp' -type d -path '*/node_modules/sharp' | head -1) && \
    sed -i '' 's/VIPS,/VIPS,\n    UHDR,/' "$SHARP_DIR/src/common.h" && \
    sed -i '' 's/{ "VipsForeignLoadJpegFile"/{ "VipsForeignLoadUhdrFile", ImageType::UHDR },\n    { "VipsForeignLoadUhdrBuffer", ImageType::UHDR },\n    { "VipsForeignLoadJpegFile"/' "$SHARP_DIR/src/common.cc" && \
    cd "$SHARP_DIR" && PYTHON=/usr/local/bin/python3.11 node-gyp rebuild

RUN pnpm build

# Deploy production dependencies only
RUN pnpm deploy --filter immich --prod /app

# Build web UI
WORKDIR /build
RUN pnpm --filter @immich/sdk --filter immich-web install --frozen-lockfile
RUN pnpm --filter @immich/sdk --filter immich-web build
RUN mkdir -p /app/www && cp -r /build/web/build/* /app/www/

# Download geodata for reverse geocoding
RUN mkdir -p /app/geodata && \
    fetch -o /app/geodata/admin1CodesASCII.txt https://download.geonames.org/export/dump/admin1CodesASCII.txt && \
    fetch -o /app/geodata/admin2Codes.txt https://download.geonames.org/export/dump/admin2Codes.txt && \
    fetch -o /app/geodata/cities500.zip https://download.geonames.org/export/dump/cities500.zip && \
    unzip -o /app/geodata/cities500.zip -d /app/geodata && \
    rm /app/geodata/cities500.zip && \
    fetch -o /app/geodata/ne_10m_admin_0_countries.geojson "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries.geojson" && \
    date +%Y-%m-%d > /app/geodata/geodata-date.txt

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG IMMICH_VERSION
ARG PACKAGES="node22 vips ffmpeg p5-Image-ExifTool libheif libraw webp"

LABEL org.opencontainers.image.title="Immich Server" \
    org.opencontainers.image.description="Immich photo management server for FreeBSD" \
    org.opencontainers.image.source="https://github.com/daemonless/immich-server" \
    org.opencontainers.image.url="https://immich.app/" \
    org.opencontainers.image.version="${IMMICH_VERSION}" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="2283" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.config-mount="/config" \
    io.daemonless.category="Media" \
    io.daemonless.packages="${PACKAGES}"

# Install runtime dependencies
RUN pkg update && \
    pkg install -y ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Copy built application from builder
COPY --from=builder /app /app

# Copy geodata and web UI from builder
COPY --from=builder /app/geodata /build/geodata
COPY --from=builder /app/www /build/www

# Create minimal corePlugin manifest (WASM plugins not supported on FreeBSD yet)
RUN mkdir -p /build/corePlugin/dist && \
    printf '{"name":"immich-core","version":"2.0.0","title":"Immich Core","description":"Core workflow (disabled)","author":"Immich Team","wasm":{"path":"dist/plugin.wasm"},"filters":[{"methodName":"filterFileName","title":"Filter by filename","description":"Filter assets by filename","supportedContexts":["asset"],"schema":{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}}],"actions":[{"methodName":"actionArchive","title":"Archive","description":"Archive asset","supportedContexts":["asset"],"schema":{}}]}' > /build/corePlugin/manifest.json

# Create directories
RUN mkdir -p /config /upload /library && \
    chown -R bsd:bsd /config /upload /library /app /build

# Copy service files
COPY root/ /
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

WORKDIR /app

ENV NODE_ENV=production
ENV IMMICH_PORT=2283
ENV UPLOAD_LOCATION=/upload
ENV IMMICH_MEDIA_LOCATION=/library

EXPOSE 2283
VOLUME /config /upload /library
