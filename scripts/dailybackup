#!/bin/sh
#Script to backup all the configurations in the /media/config folder
#The backup file will be created in /media/router/backup folder
DATA_FOLDER="/media/config"
BACKUP_FOLDER="/media/router/backup"

cd ${DATA_FOLDER};
docker compose stop $(docker ps --filter "label=needs.stop.for.backup=true" --format "{{.Names}}")
cd ${BACKUP_FOLDER};
sudo tar --ignore-failed-read -cvzf backup-$(date +%Y%m%d)_$(date +%H%M).tar.gz ${DATA_FOLDER} /etc/cron.daily /etc/cron.hourly
cd ${DATA_FOLDER};
docker compose up -d
echo $(date '+%Y-%m-%d %H:%M:%S') "CREATE - The Daily backup files has been created in ${BACKUP_FOLDER}" >> /opt/backup.log;