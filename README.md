# mongodb-backup

[![Deploy to Tutum](https://s.tutum.co/deploy-to-tutum.svg)](https://dashboard.tutum.co/stack/deploy/)

    This image extends the excellent [tutumcloud/monogodb-backup](https://github.com/tutumcloud/mongodb-backup) project.

This image syncs data between two running mongodb databases by running mongodump on the backup database and importing it to the restore mongodb database. Intermediate database dumps are saved to `/backup` and can optionally be backed up to Amazon S3.

This image may also be used for individual backup and/or restore functionality.

## Usage:

```
docker run -d \
    --env MONGODB_BACKUP_HOST=mongodb.backup.host \
    --env MONGODB_BACKUP_PORT=27017 \
    --env MONGODB_BACKUP_USER=admin \
    --env MONGODB_BACKUP_PASS=password \
    --env MONGODB_RESTORE_HOST=mongodb.restore.host \
    --env MONGODB_RESTORE_PORT=27017 \
    --env MONGODB_RESTORE_USER=admin \
    --env MONGODB_RESTORE_PASS=password \
    --env AWS_ACCESS_KEY_ID=changeme \
    --env AWS_SECRET_ACCESS_KEY=changeme \
    --env AWS_DEFAULT_REGION=us-east-1 \
    --env S3_BUCKET=changeme \
    --env S3_PATH=mongodb \
    --env S3_BACKUP=yes \
    --volume host.folder:/backup \
    --name mongodb-sync \
    agaveapi/mongodb-sync
```

Moreover, if you link `agaveapi/mongodb-sync` to a mongodb container(e.g. `tutum/mongodb`) with an alias named mongodb-backup, this image will try to auto load the source `host`, `port`, `user`, `pass` if possible. The same is true if you link `agaveapi/mongodb-sync` to a mongodb container(e.g. `tutum/mongodb`) with an alias named mongodb-restore, this image will try to auto load the destination `host`, `port`, `user`, `pass` if possible.

```
docker run -d -p 27017:27017 -p 28017:28017 -e MONGODB_PASS="mypass" --name mongodb-backup tutum/mongodb
docker run -d -p 37017:27017 -p 38017:28017 -e MONGODB_PASS="mypass" --name mongodb-restore tutum/mongodb
docker run -d --link mongodb-backup:mongodb-backup --link mongodb-restore:mongodb-restore -v host.folder:/backup agaveapi/mongodb-sync
```

## Parameters

    MONGODB_BACKUP_HOST    the host/ip of the mongodb database you wish to backup
    MONGODB_BACKUP_PORT    the port number of the mongodb database you wish to backup
    MONGODB_BACKUP_USER    the username of the mongodb database you wish to backup. If MONGODB_BACKUP_USER is empty while MONGODB_BACKUP_PASS is not, the image will use admin as the default backup database username
    MONGODB_BACKUP_PASS    the password of the mongodb database you wish to backup
    MONGODB_BACKUP_DB      the database name to dump. If not specified, it will dump all the databases
    EXTRA_BACKUP_OPTS      the extra options to pass to mongodump command

    MONGODB_RESTORE_HOST    the host/ip of the mongodb database you wish to backup
    MONGODB_RESTORE_PORT    the port number of the mongodb database you wish to backup
    MONGODB_RESTORE_USER    the username of the mongodb database you wish to backup. If MONGODB_RESTORE_USER is empty while MONGODB_RESTORE_PASS is not, the image will use admin as the default backup database username
    MONGODB_RESTORE_PASS    the password of the mongodb database you wish to backup
    MONGODB_RESTORE_DB      the database name to dump. If not specified, it will dump all the databases
    EXTRA_RESTORE_OPTS      the extra options to pass to mongodump command

    AWS_ACCESS_KEY_ID       The AWS access key for the account to which the backup will be made
    AWS_SECRET_ACCESS_KEY   The AWS secret key for the account to which the backup will be made
    AWS_DEFAULT_REGION      The default region for the backup bucket. Defaults to us-east-1
    S3_BUCKET               The name of the bucket where the backup will be copied.
    S3_PATH                 The path within the bucket where the database dump archive will be saved
    S3_BACKUP               If set, backups will be archived to S3.
    CRON_TIME               The interval of cron job to run mongodump. `0 0 * * *` by default, which is every day at 00:00
    MAX_BACKUPS             The number of backups to keep. When reaching the limit, the old backup will be discarded. No limit, by default. **Note: s3 backups will not be purged in this process. Select an expiration date in your bucket to enforce cloud backups.**

    INIT_BACKUP             If set, create a backup when the container launched
    INIT_RESTORE            If set, restore the most current backup when the container launched
    INIT_SYNC               If set, sync the two mongodb databases immediately when the container launched

## Run exclusively as a backup process

To run this image only as a backup process:

```
docker run -d \
    --env MONGODB_BACKUP_HOST=mongodb.backup.host \
    --env MONGODB_BACKUP_PORT=27017 \
    --env MONGODB_BACKUP_USER=admin \
    --env MONGODB_BACKUP_PASS=password \
    --volume host.folder:/backup \
    --name mongodb-sync \
    agaveapi/mongodb-sync backup
```

To archive copies of the the backups to S3:

```
docker run -d \
    --env MONGODB_BACKUP_HOST=mongodb.backup.host \
    --env MONGODB_BACKUP_PORT=27017 \
    --env MONGODB_BACKUP_USER=admin \
    --env MONGODB_BACKUP_PASS=password \
    --env AWS_ACCESS_KEY_ID=changeme \
    --env AWS_SECRET_ACCESS_KEY=changeme \
    --env AWS_DEFAULT_REGION=us-east-1 \
    --env S3_BUCKET=changeme \
    --env S3_PATH=mongodb \
    --env S3_BACKUP=yes \
    --volume host.folder:/backup \
    --name mongodb-sync \
    agaveapi/mongodb-sync backup
```

## Restore from a backup

To see the list of backups in a running backup container, you can run:

```
docker exec mongodb-sync ls /backup
```

To restore a mongodb database from an existing backup on disk

```
docker run -it --rm \
    --env MONGODB_RESTORE_HOST=mongodb.restore.host \
    --env MONGODB_RESTORE_PORT=27017 \
    --env MONGODB_RESTORE_USER=admin \
    --env MONGODB_RESTORE_PASS=password \
    --volume /existing/local/backup/folder:/backup \
    agaveapi/mongodb-sync /restore.sh /backup/2015.08.06.171901
```

## Run as a one-off sync process

If you have need to run one-off sync processes such as creating snapshots of your production db for testing in a QA environment, you can invoke this image as needed using the following command.

```
docker run -d --rm \
    --env MONGODB_BACKUP_HOST=mongodb.backup.host \
    --env MONGODB_BACKUP_PORT=27017 \
    --env MONGODB_BACKUP_USER=admin \
    --env MONGODB_BACKUP_PASS=password \
    --env MONGODB_RESTORE_HOST=mongodb.restore.host \
    --env MONGODB_RESTORE_PORT=27017 \
    --env MONGODB_RESTORE_USER=admin \
    --env MONGODB_RESTORE_PASS=password \
    agaveapi/mongodb-sync /sync.sh
```

If your existing mongo images are already running in containers, you can do the following:

```
docker run -d --rm \
    --links mongodb-prod:mongodb-backup \
    --links mongodb-qa:mongodb-restore \
    agaveapi/mongodb-sync /sync.sh
```
