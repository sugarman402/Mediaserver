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

### Backup and retention

To be able to backup every configuration and metadata for the stack, you need to copy the `dailyBackupCronjob` file to the `/etc/cron.daily` folder and the `hourlyBackupCronjob` to the `/etc/cron.hourly` folders. All the backup scripts contains retention logic, which could be configured according to requirements. The backup is relying on the fact that the destination is already mounted to the host to the `/media/router` folder.

### Backup destination

The destionation for the daily and hourly backup is `/media/router` which is an SMB share on the network. The mount is done by `/etc/fstab`. You need to add the SMB share's data there, something like this:

```sh
//SMB_IP_ADDRESS/PATH_TO_THE_SHARE /media/router cifs username=SMBUSER,password=SMBPASSWORD 0 0
```