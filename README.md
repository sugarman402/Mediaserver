# Mediaserver

Docker Compose media server stack configuration. Credentials and settings are stored in `.env` (use `default.env` as template).

## Setup

1. `cp default.env .env`
2. Replace `CHANGE_ME` values in `.env`
3. Configure Docker daemon (see below)
4. Mount backup destination
5. `sudo ./scripts/deploy-cron-scripts.sh`
6. `docker compose up -d`

## Docker Daemon

Configure log rotation and Cadvisor compatibility in `/etc/docker/daemon.json`:

```json
{ 
  "log-driver": "json-file",
  "features": {
    "cdi": true,
    "containerd-snapshotter": false
  },
  "log-opts": {
    "max-size": "300m",
    "max-file": "1"
  }
}
```

Then restart Docker: `sudo systemctl restart docker`

## Backup

### Destination

Backups go to `/media/router` (SMB share). Add to `/etc/fstab`:

```sh
//SMB_IP_ADDRESS/PATH_TO_THE_SHARE /media/router cifs username=SMBUSER,password=SMBPASSWORD 0 0
```

Then: `sudo mkdir -p /media/router && sudo mount -a`

### Cron Jobs

Deploy with: `sudo ./scripts/deploy-cron-scripts.sh`

Or manually:
```bash
sudo cp scripts/dailyBackupCronjob /etc/cron.daily/
sudo cp scripts/hourlyBackupCronjob /etc/cron.hourly/
sudo chmod +x /etc/cron.daily/dailyBackupCronjob /etc/cron.hourly/hourlyBackupCronjob
```

- **dailyBackupCronjob** - Full `/media/config` backup, 28-day retention
- **hourlyBackupCronjob** - qBittorrent, Tautulli, Plex DBs, 24-hour retention

Logs: `/opt/backup.log`

## Scripts

### cleanup-env-file.sh

Generates `default.env` from `.env` - replaces sensitive values with `CHANGE_ME`.

Mark sensitive lines with `#sensitive` on the preceding line:

```bash
QB_PORT=8079           # Kept as-is
#sensitive
QB_PW="mypassword"     # Becomes QB_PW=CHANGE_ME
```

Run: `./scripts/cleanup-env-file.sh`

### upgrade-compose-stack.sh

Upgrades services to latest stable versions automatically.

**Prerequisites:** `yq`, `jq`, `curl`

**Features:**
- Creates timestamped backup of `docker-compose.yaml`
- Queries Docker Hub, GHCR, GCR, Quay.io
- Filters out pre-release/platform-specific tags
- Skips `latest` tags and prevents downgrades
- Pulls new images and recreates containers

**Output:**
- ✅ Service upgraded
- ℹ️ Up-to-date or using `latest` (skipped)
- ⚠️ Unable to fetch tags

**Recovery:**

```bash
cp docker-compose.yaml.bak.TIMESTAMP docker-compose.yaml
docker compose pull && docker compose up -d
```
