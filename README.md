# immich-server

Main application server (Node.js) for [Immich](https://immich.app/).

!!! note "Part of the Immich Stack"
    This is just one component of Immich. For the complete setup (docker-compose, configuration, etc.), please see the [Daemonless Immich Stack](https://github.com/daemonless/immich).

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOSTNAME` | PostgreSQL hostname | - |
| `DB_USERNAME` | PostgreSQL username | - |
| `DB_PASSWORD` | PostgreSQL password | - |
| `DB_DATABASE_NAME` | PostgreSQL database name | - |
| `REDIS_HOSTNAME` | Redis hostname | - |
| `IMMICH_PORT` | Server listening port | `2283` |
| `UPLOAD_LOCATION` | Upload directory | `/usr/src/app/upload` |
| `IMMICH_MEDIA_LOCATION` | Media library directory | `/usr/src/app/library` |
| `IMMICH_MACHINE_LEARNING_URL` | URL to ML service (see Notes) | - |

## Quick Start

```bash
podman run -d --name immich-server \
  -p 2283:2283 \
  -e DB_HOSTNAME=immich-postgres \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=redis \
  -v /containers/immich/upload:/usr/src/app/upload \
  -v /containers/immich/library:/usr/src/app/library \
  ghcr.io/daemonless/immich-server:latest
```

## podman-compose

```yaml
services:
  immich-server:
    image: ghcr.io/daemonless/immich-server:latest
    container_name: immich-server
    environment:
      - DB_HOSTNAME=immich-postgres
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=redis
    volumes:
      - /data/immich/upload:/usr/src/app/upload
      - /data/immich/library:/usr/src/app/library
    ports:
      - 2283:2283
    restart: unless-stopped
    depends_on:
      - immich-postgres
      - redis
```

## Tags

| Tag | Source | Description |
|-----|--------|-------------|
| `:latest` | [Immich Releases](https://github.com/immich-app/immich/releases) | Latest upstream release |

## Volumes

| Path | Description |
|------|-------------|
| `/usr/src/app/upload` | Uploaded photos/videos |
| `/usr/src/app/library` | External library storage |
| `/config` | Configuration directory |

## Ports

| Port | Description |
|------|-------------|
| 2283 | Web UI and API |

## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID, default 1000)
- **Base:** Built on `ghcr.io/daemonless/base-image` (FreeBSD)
- **Machine Learning:** The `immich-ml` service requires Python bindings for onnxruntime, which are not currently available for FreeBSD. We recommend running the official `immich-machine-learning` container on a Linux host (or Linux VM/jail) and pointing this server to it via `IMMICH_MACHINE_LEARNING_URL`.
- **Ultra HDR:** Includes patched `sharp` library to support Ultra HDR images from Pixel phones (via `libvips` 8.18+).

## Links

- [Immich](https://immich.app/)
- [GitHub](https://github.com/immich-app/immich)