# MagicMirror + MMPM Unified Docker Image

A single-container Docker deployment of MagicMirror and MMPM (MagicMirror Package Manager), designed for TrueNAS SCALE. All services run in one container managed by PM2, allowing MMPM to directly restart MagicMirror after module changes.

## Why a Single Container?

MMPM's key feature is installing MagicMirror modules, which requires restarting MagicMirror afterward. In a two-container setup, MMPM cannot restart MagicMirror without mounting the Docker socket — a significant security risk. By running both in a single container with PM2, MMPM restarts MagicMirror natively via `pm2 restart magicmirror`. No Docker socket, no race conditions, no shared volume choreography.

## Features
- Single container running both MagicMirror and MMPM
- PM2 manages all processes — MMPM can restart MagicMirror automatically after module installs
- Runs as unprivileged `apps` user (UID/GID 568) — never as root
- Automated first-boot initialization of config, modules, and CSS
- MMM-mmpm module pre-installed and pre-configured
- Network settings pre-configured for headless/server use
- Tini as PID 1 for proper signal handling and zombie process reaping
- Docker healthcheck monitors MagicMirror and MMPM API availability
- Built on Node.js 24 (Debian Bookworm)

## Prerequisites
- Docker and Docker Compose installed
- TrueNAS SCALE (or any Docker-capable host)
- TrueNAS datasets with `apps` (UID/GID 568) ownership:
  - `/mnt/your-pool/magicmirror-data/config`
  - `/mnt/your-pool/magicmirror-data/modules`
  - `/mnt/your-pool/magicmirror-data/css`
  - `/mnt/your-pool/magicmirror-data/mmpm-data`

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/stevenkussmaul/magicmirror-unified.git
   cd magicmirror-unified
   ```

2. Update the volume paths in `compose.yml` to match your TrueNAS dataset paths.

3. Build and deploy:
   ```bash
   docker compose up -d --build
   ```

4. Access the applications:
   - **MagicMirror:** `http://<Your-TrueNAS-IP>:8080`
   - **MMPM Web UI:** `http://<Your-TrueNAS-IP>:7890`

## Services

All services run inside a single container, managed by PM2:

| Service        | Port | Purpose                        |
|----------------|------|--------------------------------|
| MagicMirror    | 8080 | The MagicMirror dashboard      |
| MMPM UI        | 7890 | MMPM web interface             |
| MMPM API       | 7891 | MMPM backend API               |
| MMPM Log       | 6789 | Real-time log streaming        |
| MMPM Repeater  | 8907 | WebSocket event relay           |

## Volumes

| TrueNAS Host Path                        | Container Path               |
|------------------------------------------|------------------------------|
| /mnt/your-pool/magicmirror-data/config   | /opt/magicmirror/config      |
| /mnt/your-pool/magicmirror-data/modules  | /opt/magicmirror/modules     |
| /mnt/your-pool/magicmirror-data/css      | /opt/magicmirror/css         |
| /mnt/your-pool/magicmirror-data/mmpm-data | /home/apps/.config/mmpm      |

## Troubleshooting

Check process status inside the container:
```bash
docker exec magicmirror pm2 list
```

View logs for a specific service:
```bash
docker exec magicmirror pm2 logs magicmirror
docker exec magicmirror pm2 logs mmpm-api
```

Restart MagicMirror manually (e.g., after config changes):
```bash
docker exec magicmirror pm2 restart magicmirror
```

## Networking

This image is deployed using macvlan networking, giving the container its own IP address on the LAN. This is required because MMPM's Angular UI has hardcoded port numbers (7891, 6789, 8907) — the browser constructs API and WebSocket URLs using `window.location.hostname` plus these fixed ports. With bridge networking and remapped host ports, those connections fail. With macvlan, all container ports are directly reachable at the container's LAN IP.

### Accessing the Services

With macvlan, access services directly by container IP — no port remapping:

- **MagicMirror:** `http://192.168.54.12:8080`
- **MMPM UI:** `http://192.168.54.12:7890`

### Macvlan Network Setup

The `image-compose.yml` defines a self-contained macvlan network (`macvlan_mm`) — no pre-created Docker network or external dependencies required. Update the IP, subnet, gateway, and parent interface to match your environment before deploying.

---

## Future Improvements

### Clean URL Access (no port in URL)

The root cause of the macvlan requirement is that MMPM's Angular UI hardcodes ports 7891, 6789, and 8907 in 3 source files:

- `ui/src/app/services/api/base-api.ts`
- `ui/src/app/components/log-stream-viewer/log-stream-viewer.component.ts`
- `ui/src/app/components/magicmirror-controller/magicmirror-controller.component.ts`

The correct fix is to make these ports runtime-configurable via `mmpm-env.json`. The Python backend already reads this file and exposes values to the Angular UI — adding the three port values there allows the UI to use relative URLs when ports are set to `0`, with no rebuild required. Default values remain unchanged so existing Pi/native installs are unaffected.

If this is implemented (either as an upstream PR to `Bee-Mar/mmpm` or as a fork):
1. Set `MMPM_API_SERVER_PORT`, `MMPM_LOG_SERVER_PORT`, and `MMPM_REPEATER_SERVER_PORT` to `0` in `mmpm-env.json`
2. Switch `image-compose.yml` back to bridge networking with standard port mappings
3. Add location blocks to your external reverse proxy to route `/api/*`, `/log-ws/*`, and `/rpt-ws/*` to their respective container ports alongside the main UI proxy
4. Access both services via clean hostnames with no port required

This would allow `mmpm.yourdomain.com` through a standard reverse proxy with no macvlan required. No nginx inside the container needed.

---

## Design Notes

### IP Whitelist

The MagicMirror config sets `ipWhitelist: []` to allow connections from any IP. This is required for container networking (the browser connects from outside the container) but means the dashboard is accessible to anyone on your network. Use firewall rules to restrict access if needed.

### Why `MMPM_IS_DOCKER_IMAGE` Is Set to `false`

MMPM has a config flag `MMPM_IS_DOCKER_IMAGE` intended for multi-container setups where MMPM runs in its own container. When `true`, it blocks CLI commands like `mmpm mm-ctl --restart`, `mmpm mm-ctl --stop`, and `mmpm upgrade` — assuming Docker orchestration handles process management instead.

This project sets it to `false` because our single-container architecture uses PM2, not Docker, to manage processes. Setting it to `false` allows:

- `mmpm mm-ctl --restart` to call `pm2 restart magicmirror` (via the `MMPM_MAGICMIRROR_PM2_PROCESS_NAME` config)
- Full MMPM CLI access when exec'ing into the container for debugging
- The MMPM web UI to trigger MagicMirror restarts after module installs

The only downside is that `mmpm upgrade` will run but changes are lost on container rebuild — use `docker compose build` to update MMPM instead.
