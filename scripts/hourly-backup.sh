#!/bin/sh
#Script to backup Plex Database and Utorrent Server files hourly
#The backup file will be created in /media/router/backup folder
DATA_FOLDER="/media/config"
BACKUP_FOLDER="/media/router/backup"

cd $BACKUP_FOLDER;
sudo tar -cvzf backup-plexdb$(date +%Y%m%d)_$(date +%H%M).tar.gz ${DATA_FOLDER}/qbittorrent ${DATA_FOLDER}/tautulli ${DATA_FOLDER}/plex/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases
echo $(date '+%Y-%m-%d %H:%M:%S') "CREATE - The Hourly backup files has been created in /media/router/backup/" >> /opt/backup.log;