# Immich Server for FreeBSD

Main [Immich](https://immich.app/) application server (Node.js).

## Usage

```bash
podman run -d --name immich-server \
  -e DB_URL=postgres://postgres:postgres@immich-postgres:5432/immich \
  -e REDIS_URL=redis://redis:6379 \
  -v /containers/immich/upload:/upload \
  -v /containers/immich/library:/library \
  -p 2283:2283 \
  ghcr.io/daemonless/immich-server:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DB_URL | - | PostgreSQL connection string |
| REDIS_URL | - | Redis connection string |
| IMMICH_PORT | 2283 | Server port |
| UPLOAD_LOCATION | /upload | Upload directory |
| IMMICH_MEDIA_LOCATION | /library | Media library directory |

## Volumes

- `/upload` - Uploaded photos/videos
- `/library` - External libraries
- `/config` - Configuration

## Ports

- `2283` - Web interface and API

## FreeBSD-Specific Notes

### Ultra HDR Support

FreeBSD's vips 8.18 includes Ultra HDR (UHDR) support via libultrahdr, which is
more current than the libvips 8.17.3 bundled with sharp's Linux prebuilds.
However, sharp's loader map doesn't yet recognize the UHDR loader, causing
"unsupported image format" errors for Ultra HDR images from Pixel phones.

The Containerfile includes a patch that adds UHDR to sharp's ImageType enum and
loader map, then rebuilds the native module. This enables proper handling of
Ultra HDR images until sharp adds official support upstream.

### ML Service

The ML service (immich-ml) requires onnxruntime, which doesn't have FreeBSD
support yet. For face recognition and smart search features, route ML requests
to a Linux host running immich-ml.

## Part of Immich for FreeBSD

See [daemonless/immich](https://github.com/daemonless/immich) for the complete stack.
