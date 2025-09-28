#!/bin/sh
#Daily scripts
#Script to delete files older than 4 weeks
DATA_FOLDER="/media/config"
BACKUP_FOLDER="/media/router/backup"
HMOLDERTHAN4WEEKS=$(find ${BACKUP_FOLDER}/ -type f -mtime 28 -name '*.gz' | wc -l)
if  [ $HMOLDERTHAN4WEEKS > 1 ];
then
find ${BACKUP_FOLDER}/ -type f -mtime 28 -name '*.gz' -execdir rm -- {} +;
echo $(date '+%Y-%m-%d %H:%M:%S') "DELETE - The backup files that older than 28 days has been deleted from ${BACKUP_FOLDER}/" >> /opt/backup.log;
else
echo $(date '+%Y-%m-%d %H:%M:%S') "DELETE - No 28 days older backup files has been deleted" >> /opt/backup.log;
fi

#Script to delete utplexdb files older than 24 hours !/bin/sh
HMOLDERTHAN24HOURS=$(find ${BACKUP_FOLDER} -type f -mmin +1440 -name 'backup-plexdb*.gz' -execdir rm -- {} +)
if  [ $HMOLDERTHAN24HOURS > 0 ];
then
find ${BACKUP_FOLDER} -type f -mmin +1440 -name 'backup-plexdb*.gz' -execdir rm -- {} +;
echo $(date '+%Y-%m-%d %H:%M:%S') "DELETE - The backup files that older than 24 hours has been deleted from ${BACKUP_FOLDER}/" >> /opt/backup.log;
else
echo $(date '+%Y-%m-%d %H:%M:%S') "DELETE - No 24 hours older backup files has been deleted" >> /opt/backup.log;
fi