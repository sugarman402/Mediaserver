# Mediaserver

Docker Compose media server stack configuration. Credentials and settings are stored in `.env` (use `default.env` as template).

## Prepare host (based on Ubuntu distribution)

```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl mc net-tools smartmontools git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

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
sudo cp scripts/upgradeComposeStack /etc/cron.weekly/
sudo chmod +x /etc/cron.daily/dailyBackupCronjob /etc/cron.hourly/hourlyBackupCronjob /etc/cron.weekly/upgradeComposeStack
```

- **dailyBackupCronjob** - Full `/media/config` backup, 28-day retention
- **hourlyBackupCronjob** - qBittorrent, Tautulli, Plex DBs, 24-hour retention
- **upgradeComposeStack** - upgrade Docker Compose stack and sends status report

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

### upgradeComposeStack

Upgrades services to latest stable versions automatically.

**Prerequisites:** `yq`, `jq`, `curl`

**Features:**
- Creates timestamped backup of `docker-compose.yaml`
- Queries Docker Hub, GHCR, GCR, Quay.io
- Filters out pre-release/platform-specific tags
- Skips `latest` tags and prevents downgrades
- Pulls new images and recreates containers
- Sends status report to Discord channel

**Recovery:**

```bash
cp docker-compose.yaml.bak.TIMESTAMP docker-compose.yaml
docker compose pull && docker compose up -d
```

### Discord Notifications

The upgradeComposeStack script will automatically send a notification to your configured Discord webhook about the result of each upgrade (success or failure, with details on any failed containers). Set the `DISCORD_WEBHOOK_URL` variable in your `.env` file to enable this feature.

## Manual Configuration for Service Data Files

Some services require manual creation or editing of configuration files in addition to .env variables. Below are the main components and the files you may need to create or edit:

| Service         | Config Path                                              | Description/Action Required                |
|-----------------|----------------------------------------------------------|--------------------------------------------|
| Alertmanager    | alertmanager/config.yml                                  | Define routing, receivers, and rules       |
| Grafana         | grafana/config.monitoring                                | username, password for GUI access          |
| PlexTraktSync   | plextraktsync/config.yml, plextraktsync/servers.yml      | Plex/Trakt tokens, server URLs             |

> For each service above, copy a sample config from the official documentation or your previous setup, and adjust as needed. Some services will auto-generate these files on first run, but you may want to pre-populate them for easier migration or backup.
