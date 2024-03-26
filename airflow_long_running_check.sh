#!/bin/bash
set -x

SLACK_WEBHOOK_URL=$DATA_ALERT_WEBHOOK

send_alert_to_slack() {
    local pod_name=$1
    local message="Pod ${pod_name} has exceeded its threshold runtime of "$threshold" "
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL
}

pods=$(kubectl get pods -o json)

echo "${pods}" | jq -c '.items[] | select(.metadata.name | test("dag"))' | while read -r pod; do
    pod_name=$(echo "${pod}" | jq -r '.metadata.name')
    echo $pod_name
    threshold=$(echo "${pod}" | jq -r '.metadata.annotations."monitor.kubernetes.io/threshold" // empty')
    echo $threshold
    
    if [ -z "$threshold" ]; then
        echo "No threshold set for $pod_name. Using default threshold of 3 hours."
        threshold=10800
    fi
    echo "Threshold for $pod_name is $threshold hours."

    start_time=$(echo "${pod}" | jq -r '.status.startTime')
    
    if [ "$start_time" == "null" ]; then
        echo "Start time for $pod_name is null. Pod might not have started yet."
        continue
    fi
    
    start_time_s=$(date --date="$start_time" +%s)
    now_s=$(date +%s)
    runtime=$((now_s - start_time_s))

    if [ "$runtime" -gt "$threshold" ]; then
        echo "$pod_name has exceeded threshold"
        if [[ $pod_name == *-* ]] && [[ ! $pod_name == *test* ]]; then
            send_alert_to_slack "${pod_name}"
        else
            echo "Pod name does not meet criteria, ignoring"
        fi
    else
        echo "$pod_name has not exceeded threshold"
    fi
done
