#!/bin/bash
set -x
BACKUP_NAME=clickhouse_backup
slack_webhook=""
upload_success_message="clickhouse backup successfully uploaded to S3 bucket"
backup_failed_message="clickhouse-backup create $BACKUP_NAME FAILED and return $? exit code"
upload_failed_message="clickhouse-backup upload $BACKUP_NAME FAILED and return $? exit code"

/root/build/linux/amd64/clickhouse-backup create $BACKUP_NAME -c /config.yml >> /var/log/clickhouse-backup.log
if [[ $? != 0 ]]; then
  curl -X POST --data-urlencode "payload={\"channel\": \"#backup-alerts\", \"username\": \"webhookbot\", \"text\": \"$backup_failed_message\", \"icon_emoji\": \":bar_chart\"}" $slack_webhook
fi
tar -zcvf $BACKUP_NAME.tar.gz /data/clickhouse/backup/$BACKUP_NAME
aws s3 cp $BACKUP_NAME.tar.gz s3://clickhouse_backup/
if [[ $? != 0 ]]; then
   curl -X POST --data-urlencode "payload={\"channel\": \"#backup-alerts\", \"username\": \"webhookbot\", \"text\": \"$upload_failed_message\", \"icon_emoji\": \":bar_chart\"}" $slack_webhook
else
   curl -X POST --data-urlencode "payload={\"channel\": \"#backup-alerts\", \"username\": \"webhookbot\", \"text\": \"$upload_success_message\", \"icon_emoji\": \":bar_chart\"}" $slack_webhook  
fi
