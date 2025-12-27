# Immich Server for FreeBSD

Main [Immich](https://immich.app/) application server (Node.js).

## Usage

```bash
podman run -d --name immich-server \
  -e DB_HOSTNAME=immich-postgres \
  -e DB_USERNAME=immich \
  -e DB_PASSWORD=immich \
  -e DB_DATABASE_NAME=immich \
  -e REDIS_HOSTNAME=immich-redis \
  -v /containers/immich/upload:/usr/src/app/upload \
  -v /containers/immich/library:/usr/src/app/library \
  -p 2283:2283 \
  ghcr.io/daemonless/immich-server:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DB_HOSTNAME | - | PostgreSQL hostname |
| DB_USERNAME | - | PostgreSQL username |
| DB_PASSWORD | - | PostgreSQL password |
| DB_DATABASE_NAME | - | PostgreSQL database name |
| REDIS_HOSTNAME | - | Redis hostname |
| IMMICH_PORT | 2283 | Server port |
| UPLOAD_LOCATION | /usr/src/app/upload | Upload directory |
| IMMICH_MEDIA_LOCATION | /usr/src/app/library | Media library directory |

## Volumes

- `/usr/src/app/upload` - Uploaded photos/videos
- `/usr/src/app/library` - External libraries
- `/config` - Configuration

Note: Volume paths match the official Linux image for drop-in compatibility.

## Ports

- `2283` - Web interface and API

## FreeBSD-Specific Notes

### Drop-in Linux Compatibility

This image uses the same volume paths as the official Linux image, allowing
migration between Linux and FreeBSD without changing your data layout.

### Ultra HDR Support

FreeBSD's vips 8.18 includes Ultra HDR (UHDR) support via libultrahdr, which is
more current than the libvips 8.17.3 bundled with sharp's Linux prebuilds.
The Containerfile includes a patch that adds UHDR to sharp's loader map,
enabling proper handling of Ultra HDR images from Pixel phones.

### Workflow Plugins (WASM)

The corePlugin (workflow automation) is copied from the official Linux image
since the extism-js build tool doesn't have FreeBSD releases. WASM plugins
run fine on FreeBSD - only the build tooling is missing.

### ML Service (Remote)

The ML service (immich-ml) requires onnxruntime Python bindings, which aren't
available for FreeBSD. Run immich-ml on a Linux host and configure this server
to connect to it:

**Option 1: Admin UI** (recommended)
- Go to Administration → Settings → Machine Learning
- Add URL: `http://<linux-host>:3003`

**Option 2: Environment Variable**
```bash
-e IMMICH_MACHINE_LEARNING_URL=http://<linux-host>:3003
```

This gives you full ML functionality: face recognition, smart search, and
image classification.

## Part of Immich for FreeBSD

See [daemonless/immich](https://github.com/daemonless/immich) for the complete stack.
