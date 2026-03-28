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
   git clone https://github.com/your-username/magicmirror-unified.git
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

| TrueNAS Host Path                          | Container Path               |
|--------------------------------------------|------------------------------|
| /mnt/your-pool/magicmirror-data/config     | /opt/magicmirror/config      |
| /mnt/your-pool/magicmirror-data/modules    | /opt/magicmirror/modules     |
| /mnt/your-pool/magicmirror-data/css        | /opt/magicmirror/css         |
| /mnt/your-pool/magicmirror-data/mmpm-data  | /home/apps/.config/mmpm      |

## Security Note

The MagicMirror config sets `ipWhitelist: []` to allow connections from any IP. This is required for container networking (the browser connects from outside the container) but means the dashboard is accessible to anyone on your network. Use firewall rules to restrict access if needed.

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
