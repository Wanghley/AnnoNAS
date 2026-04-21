# Linux Voice Assistant on Orange Pi 3B+

This stack is prepared for production-style deployment on Orange Pi 3B+ (ARM64) with Docker Compose.

## What this deployment includes

- ARM64 platform default (`linux/arm64`)
- One-shot permission bootstrap service (`fix-permissions`)
- ALSA device passthrough (`/dev/snd`) for headless SBC reliability
- Rotating container logs to avoid SD card exhaustion
- Healthcheck and graceful shutdown behavior
- Audio-friendly runtime limits (`SYS_NICE`, `rtprio`, `memlock`)

## Prerequisites (Orange Pi 3B+)

1. 64-bit Linux userspace (Armbian/Ubuntu recommended)
2. Docker Engine + Docker Compose plugin installed
3. User is in `docker` and `audio` groups
4. Host audio devices available under `/dev/snd`

Quick checks:

```bash
uname -m
# expected: aarch64

ls -l /dev/snd
id
```

## Configuration

1. Create your env file:

```bash
cp .env.example .env
```

2. Review `.env` values:

- `LVA_USER_ID` and `LVA_USER_GROUP` must match the host user running Docker.
- Keep `LVA_SOUNDCARD_BACKEND=alsa` for headless Orange Pi unless you specifically use PulseAudio/PipeWire.
- Keep `DOCKER_PLATFORM=linux/arm64`.

Get current IDs:

```bash
id -u
id -g
```

## Deploy

From this folder (`arlo/LVA`):

```bash
docker compose pull
docker compose up -d
```

## Validate

```bash
docker compose ps
docker compose logs --tail=100 linux-voice-assistant
```

Health status:

```bash
docker inspect --format='{{json .State.Health}}' linux-voice-assistant
```

## Operational notes

- If you run PipeWire/PulseAudio and need that route, set:
  - `LVA_SOUNDCARD_BACKEND=pulse`
  - `LVA_XDG_RUNTIME_DIR`, `LVA_PULSE_SERVER`, `LVA_PULSE_COOKIE` to valid host paths
- Logs are capped at 3 files x 10MB per container.
- Resource limits are set for SBC stability and can be tuned in `docker-compose.yml`.

## Troubleshooting

- No audio input/output:
  - Verify `/dev/snd` exists and permissions allow your user/group.
  - Confirm user IDs in `.env` match host values.
- Container restarts repeatedly:
  - Check `docker compose logs linux-voice-assistant` for backend/device errors.
- Permission issues in volumes:
  - Re-run bootstrap: `docker compose up fix-permissions`
