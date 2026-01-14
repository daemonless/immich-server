# Immich Server

Immich photo management server on FreeBSD.

| | |
|---|---|
| **Port** | 2283 |
| **Registry** | `ghcr.io/daemonless/immich-server` |
| **Source** | [https://github.com/immich-app/immich](https://github.com/immich-app/immich) |
| **Website** | [https://immich.app/](https://immich.app/) |

## Deployment

### Podman Compose

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
          - REDIS_HOSTNAME=immich-redis
          - PUID=1000
          - PGID=1000
          - TZ=UTC
        volumes:
          - /path/to/containers/immich/config:/config
          - /path/to/containers/immich/data:/data
        ports:
          - 2283:2283
    restart: unless-stopped
```

### Podman CLI

```bash
podman run -d --name immich-server \
  -p 2283:2283 \
  -e DB_HOSTNAME=immich-postgres \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=immich-redis \
  -e PUID=@PUID@ \
  -e PGID=@PGID@ \
  -e TZ=@TZ@ \
  -v /path/to/containers/immich/config:/config \ 
  -v /path/to/containers/immich/data:/data \ 
  ghcr.io/daemonless/immich-server:latest
```
Access at: `http://localhost:2283`

### Ansible

```yaml
- name: Deploy immich-server
  containers.podman.podman_container:
    name: immich-server
    image: ghcr.io/daemonless/immich-server:latest
    state: started
    restart_policy: always
    env:
      DB_HOSTNAME: "immich-postgres"
      DB_USERNAME: "postgres"
      DB_PASSWORD: "postgres"
      DB_DATABASE_NAME: "immich"
      REDIS_HOSTNAME: "immich-redis"
      PUID: "@PUID@"
      PGID: "@PGID@"
      TZ: "@TZ@"
    ports:
      - "2283:2283"
    volumes:
      - "/path/to/containers/immich/config:/config"
      - "/path/to/containers/immich/data:/data"
```

## Configuration
### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOSTNAME` | `immich-postgres` | Postgres database hostname |
| `DB_USERNAME` | `postgres` | Postgres database user |
| `DB_PASSWORD` | `postgres` | Postgres database password |
| `DB_DATABASE_NAME` | `immich` | Postgres database name |
| `REDIS_HOSTNAME` | `immich-redis` | Redis hostname |
| `PUID` | `1000` | User ID for the application process |
| `PGID` | `1000` | Group ID for the application process |
| `TZ` | `UTC` | Timezone for the container |
### Volumes

| Path | Description |
|------|-------------|
| `/config` | Configuration directory (unused but mounted) |
| `/data` | Media storage (photos, videos, thumbnails) |
### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `2283` | TCP | Web UI/API |

This image is part of the [Immich Stack](https://daemonless.io/images/immich).

## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID)
- **Base:** Built on `ghcr.io/daemonless/base` (FreeBSD)