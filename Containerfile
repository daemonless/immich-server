# Immich Server for FreeBSD
# Main application server (Node.js)

ARG BASE_VERSION=15
ARG IMMICH_VERSION=v2.4.1

# Pull Linux image for pre-built corePlugin WASM (extism-js has no FreeBSD release)
FROM --platform=linux/amd64 ghcr.io/immich-app/immich-server:${IMMICH_VERSION} AS linux-immich

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
    cd "$SHARP_DIR/src" && PYTHON=/usr/local/bin/python3.11 node-gyp rebuild

RUN pnpm build

# Deploy production dependencies only
RUN pnpm deploy --filter immich --prod /app && \
    SHARP_BUILD=$(find /build/node_modules/.pnpm -name 'sharp-freebsd-x64.node' -path '*/src/build/Release/*' | head -1) && \
    SHARP_DEST=$(find /app/node_modules/.pnpm -name 'sharp' -type d -path '*/node_modules/sharp' | head -1) && \
    mkdir -p "$SHARP_DEST/src/build/Release" && \
    cp "$SHARP_BUILD" "$SHARP_DEST/src/build/Release/"

# Build web UI (increase heap for vite build)
WORKDIR /build
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm --filter @immich/sdk --filter immich-web install --frozen-lockfile
RUN pnpm --filter @immich/sdk --filter immich-web build
RUN mkdir -p /app/www && cp -r /build/web/build/* /app/www/

# Copy pre-built corePlugin from Linux image (extism-js doesn't have FreeBSD releases)
# The WASM plugin is platform-independent, so we can use the Linux build
COPY --from=linux-immich /build/corePlugin /app/corePlugin

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
    io.daemonless.category="Photos & Media" \
    io.daemonless.upstream-mode="github" \
    io.daemonless.upstream-repo="immich-app/immich" \
    io.daemonless.packages="${PACKAGES}"

# Install runtime dependencies
# Remove GCC compiler binaries (keep runtime libs) - saves ~155MB
RUN pkg update && \
    pkg install -y ${PACKAGES} && \
    mkdir -p /app && echo "${IMMICH_VERSION}" | sed 's/^v//' > /app/version && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/* && \
    rm -rf /usr/local/libexec/gcc14 /usr/local/bin/lto-dump14 && \
    rm -f /usr/local/lib/libopcodes* /usr/local/lib/libbfd*

# Copy built application from builder (with correct ownership)
COPY --from=builder --chown=bsd:bsd /app /app

# Create directories and symlinks (paths match Linux immich expectations)
# www, corePlugin, and geodata are in /app but immich expects them in /build
# Permissions: bsd user needs read access to symlinks, write access to geodata
RUN mkdir -p /config /data /build && \
    chown bsd:bsd /config /data /build && \
    ln -sf /app/www /build/www && \
    ln -sf /app/corePlugin /build/corePlugin && \
    ln -sf /app/geodata /build/geodata && \
    chown -h bsd:bsd /build/www /build/corePlugin /build/geodata && \
    chmod 755 /app/geodata && chmod 644 /app/geodata/*

# Copy service files
COPY root/ /
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

WORKDIR /app

ENV NODE_ENV=production
ENV IMMICH_PORT=2283
ENV IMMICH_MEDIA_LOCATION=/data

EXPOSE 2283
VOLUME /config /data
