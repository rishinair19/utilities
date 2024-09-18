#!/bin/bash

slack_webhook=$DATA_ALERT_WEBHOOK
mysql -h $MYSQL_HOST -u $DATA_MYSQL_USERNAME -p$DATA_MYSQL_PASSWORD -D $DB_NAME -e "select dag_id,dttm,owner,extra from log where event='paused' AND dttm > now() - interval 1 hour" > /tmp/dump
tail +2 /tmp/dump >> /tmp/output

while read line; do
    dag_id=$(echo $line | awk '{print $1}')
    owner=$(echo $line | awk '{print $4}')
    dttm=$(echo $line | awk '{print $3}' | cut -c -5)
    condition=$(echo $line | awk '{print $6}' | cut -c -6 ) 
    if [[ "$condition" =~ "true" ]]; then
       SQL_QUERY="SELECT dag_id, MIN(execution_date) AS first_run FROM dag_run GROUP BY dag_id HAVING MIN(execution_date) > NOW() - INTERVAL 1 DAY;"
       mysql -u "$DATA_MYSQL_USERNAME" -p"$DATA_MYSQL_PASSWORD" -h $MYSQL_HOST -D $DB_NAME -e "$SQL_QUERY" >/tmp/new_dags
       NEW_DAG=$(cat /tmp/new_dags | tail -n +2 | awk '{print $1}') 
       if [[ "$dag_id" == "$NEW_DAG" ]]; then
         echo "This is a newly created dag, it can be ignored"
       else
        echo "Dag "$dag_id was paused by "$owner at $dttm"
        curl -X POST --data-urlencode "payload={\"username\": \"SRE-BOT\", \"text\": \"$dag_id was paused by "$owner" at $dttm UTC\", \"icon_emoji\": \":robot_face\"}" $slack_webhook
       fi  
    else
        echo "No dags were paused in last hour"
    fi
done < /tmp/output
rm -f /tmp/dump /tmp/output /tmp/new_dags