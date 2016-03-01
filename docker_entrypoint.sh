#!/bin/bash

function docron() {

  touch /mongo_sync.log
  tail -f /mongo_sync.log &
  crontab /crontab.conf
  echo "=> Running cron job"
  exec cron -f

}

env > /crontab.conf

if [[ "${1}" == "backup" ]]; then

    if [ -n "${INIT_BACKUP}" ]; then
        echo "=> Create a backup on the startup"
        /backup.sh
    fi

    echo "=> Adding backup crontab entry"
    echo "${CRON_TIME} /backup.sh >> /mongo_sync.log 2>&1" >> /crontab.conf

    docron

elif [[ "${1}" == "restore" ]]; then

    if [ -n "${INIT_RESTORE}" ]; then
        echo "=> Restore a backup on the startup"
        /restore.sh
    fi

    echo "=> Adding restore crontab entry"
    echo "${CRON_TIME} /restore.sh >> /mongo_sync.log 2>&1" >> /crontab.conf

    docron

elif [[ -z "${1}" || "${1}" == "sync" ]]; then

    if [ -n "${INIT_SYNC}" ]; then
        echo "=> Synchronize on the startup"
        /sync.sh
    fi

    echo "=> Adding sync crontab entry"
    echo "${CRON_TIME} /backup.sh >> /mongo_sync.log 2>&1" >> /crontab.conf

    docron

else

  # echo "Unrecognized action. Please specify one of: backup, restore, sync"
  # exit 64
  exec "$@"

fi
