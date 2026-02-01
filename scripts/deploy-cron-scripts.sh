#!/bin/bash
# Deploy backup cronjob scripts to /etc/cron.daily and /etc/cron.hourly
# Usage: sudo ./deploy-cron-scripts.sh

set -e

# Get the directory where this script is located
DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if running as root
[ "$EUID" -ne 0 ] && echo "Error: Run with sudo" && exit 1

# Function to deploy a cron script
deploy() {
    local src="$1" dest="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dest"
        chown root:root "$dest"
        chmod 755 "$dest"
        echo "✓ Deployed: $dest"
    else
        echo "✗ Not found: $src"
    fi
}

echo "Deploying cron scripts from $DIR..."
deploy "$DIR/dailyBackupCronjob" "/etc/cron.daily/dailyBackupCronjob"
deploy "$DIR/hourlyBackupCronjob" "/etc/cron.hourly/hourlyBackupCronjob"
deploy "$DIR/upgradeComposeStack" "/etc/cron.weekly/upgradeComposeStack"
echo "Done!"
