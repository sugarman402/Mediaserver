# Mediaserver

This repository holds the configuration for the mediaserver stack, based on `Docker` and `Docker Compose`. All the credentials and Compose stack configurations are stored in the `.env` file, which is the `default.env` here and need to be propagated with data.
However it's not a best practice, this stack is relying on `latest` image tags in almost all of the services to avoid the hassle of bumping the container image versions each upgrade iterations. 

## Docker Daemon

To be able to configure the log rotation for Docker and a use workaround for Docker's min API level issue with Cadvisor, you need to modify the content for the configuration file for Docker in `/etc/docker/daemon.json` to look like this: 

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

After editing the configuration file, restart the Docker daemon to apply the changes:

```bash
sudo systemctl restart docker
```

Verify the configuration is applied correctly:

```bash
docker info | grep -A 5 "Logging Driver"
```

### Backup and retention

To be able to backup every configuration and metadata for the stack, you need to copy the `dailyBackupCronjob` file to the `/etc/cron.daily` folder and the `hourlyBackupCronjob` to the `/etc/cron.hourly` folders. All the backup scripts contains retention logic, which could be configured according to requirements. The backup is relying on the fact that the destination is already mounted to the host to the `/media/router` folder.

To set up the backup cron jobs:

```bash
sudo cp scripts/dailyBackupCronjob /etc/cron.daily/
sudo cp scripts/hourlyBackupCronjob /etc/cron.hourly/
sudo chmod +x /etc/cron.daily/dailyBackupCronjob
sudo chmod +x /etc/cron.hourly/hourlyBackupCronjob
```

Verify the cron jobs are executable:

```bash
ls -l /etc/cron.daily/dailyBackupCronjob
ls -l /etc/cron.hourly/hourlyBackupCronjob
```

### Backup destination

The destionation for the daily and hourly backup is `/media/router` which is an SMB share on the network. The mount is done by `/etc/fstab`. You need to add the SMB share's data there, something like this:

```sh
//SMB_IP_ADDRESS/PATH_TO_THE_SHARE /media/router cifs username=SMBUSER,password=SMBPASSWORD 0 0
```

After editing `/etc/fstab`, create the mount point and mount the share:

```bash
sudo mkdir -p /media/router
sudo mount -a
```

Verify the mount is successful:

```bash
df -h | grep /media/router
```

## Upgrading the Stack

The `scripts/upgrade-compose-stack.sh` script provides an automated way to upgrade Docker Compose services to their latest stable versions. This script intelligently queries container registries, identifies the newest semantic versions, and updates your `docker-compose.yaml` file accordingly.

### Prerequisites

Before running the upgrade script, ensure the following dependencies are installed:

- **yq** (v4 or higher) - YAML processor
- **jq** - JSON processor
- **curl** - Command-line HTTP client

You can check if these are installed by running:

```bash
yq --version
jq --version
curl --version
```

### How It Works

The upgrade script performs the following operations:

1. **Backup Creation**: Automatically creates a timestamped backup of your `docker-compose.yaml` file (e.g., `docker-compose.yaml.bak.1737484800`)

2. **Registry Support**: Queries the following container registries for available tags:
   - Docker Hub (docker.io)
   - GitHub Container Registry (ghcr.io)
   - Google Container Registry (gcr.io)
   - Quay.io (quay.io)

3. **Smart Tag Selection**: Filters out non-stable tags including:
   - Pre-release versions (alpha, beta, rc, dev, nightly, edge)
   - Platform-specific tags (amd64, arm64, alpine, ubuntu, etc.)
   - Test/preview builds

4. **Semantic Versioning**: Identifies the latest stable version using semantic versioning rules (e.g., `1.2.3`, `v2.4.5`, `3.1.0-1`)

5. **Version Safety**: 
   - Skips services using the `latest` tag
   - Prevents downgrades (won't replace a newer version with an older one)
   - Only upgrades when a newer version is available

6. **Automatic Deployment**: After updating the compose file:
   - Pulls the new images
   - Recreates containers with updated images
   - Removes unused/old images to save disk space

### Usage

**Important**: The script must be run from the same directory as your `docker-compose.yaml` file, or the `docker-compose.yaml` file must be in the current working directory. The script expects to find `docker-compose.yaml` in the current directory.

### Output Indicators

- **✅** - Service will be upgraded to a newer version
- **ℹ️** - Service is up-to-date or using `latest` tag (skipped)
- **⚠️** - Unable to fetch tags or registry not supported (no changes)

### Backup Recovery

If something goes wrong after an upgrade, you can restore from the automatic backup:

```bash
# Find your backup file
ls -la docker-compose.yaml.bak.*

# Restore the backup (replace timestamp with your backup file)
cp docker-compose.yaml.bak.1737484800 docker-compose.yaml

# Redeploy with the old configuration
docker compose pull && docker compose up -d
```

### Best Practices

1. **Review Changes**: After the script completes, review the changes made to `docker-compose.yaml` before the containers start:
   ```bash
   git diff docker-compose.yaml
   ```

2. **Monitor Services**: Check service logs after upgrade to ensure everything is running correctly:
   ```bash
   docker compose logs -f
   ```
