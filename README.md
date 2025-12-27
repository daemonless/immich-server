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

## Part of Immich for FreeBSD

See [daemonless/immich](https://github.com/daemonless/immich) for the complete stack.
