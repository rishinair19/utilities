#!/bin/bash
set -x

while true; do
    job_rows_deleted=$(mysql -u"$USER" -p"$PASSWORD" -h "$HOST" "$DATABASE" -se "DELETE FROM job WHERE start_date < NOW() - INTERVAL 60 DAY LIMIT 50000; SELECT ROW_COUNT();")
    
    log_rows_deleted=$(mysql -u"$USER" -p"$PASSWORD" -h "$HOST" "$DATABASE" -se "DELETE FROM log WHERE dttm < NOW() - INTERVAL 60 DAY LIMIT 50000; SELECT ROW_COUNT();")
    
    task_instance_rows_deleted=$(mysql -u"$USER" -p"$PASSWORD" -h "$HOST" "$DATABASE" -se "DELETE FROM task_instance WHERE start_date < NOW() - INTERVAL 60 DAY LIMIT 50000; SELECT ROW_COUNT();")

    xcom_rows_deleted=$(mysql -u"$USER" -p"$PASSWORD" -h "$HOST" "$DATABASE" -se "DELETE FROM xcom WHERE timestamp < NOW() - INTERVAL 60 DAY LIMIT 50000; SELECT ROW_COUNT();")

    dag_run_deleted=$(mysql -u"$USER" -p"$PASSWORD" -h "$HOST" "$DATABASE" -se "DELETE FROM dag_run WHERE execution_date < NOW() - INTERVAL 60 DAY LIMIT 50000; SELECT ROW_COUNT();")

    if [[ "$job_rows_deleted" -lt 100 ]] && [[ "$log_rows_deleted" -lt 100 ]] && [[ "$task_instance_rows_deleted" -lt 100 ]] && [[ "$xcom_rows_deleted" -lt 100 ]] && [[ "$dag_run_deleted" -lt 100 ]] ; then
        echo "No more rows to delete."
        break
    fi
    sleep 10
done

echo "Queries executed successfully, airflow has been cleaned up"