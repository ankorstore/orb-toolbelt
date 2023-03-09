#!/bin/bash

if [ -z "$BASH" ]; then
  echo "Bash not installed. Aborting."
  exit 1
fi
hash jq 2>/dev/null || { echo >&2 "jq is not installed. Aborting."; exit 1; }
hash curl 2>/dev/null || { echo >&2 "curl is not installed. Aborting."; exit 1; }
if [ -z "$CIRCLE_TOKEN" ]; then
  echo "CIRCLE_TOKEN env not set. Please set a valid CircleCi API Token in the env var CIRCLE_TOKEN";
  exit 1;
fi

mkdir -p /tmp/aks

get_job_status() {
  local NAME_OF_JOB="$1"
  local STATUS=""
  local NUMBER=""
  local WORKFLOW_JOBS_URL="https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/job?circle-token=$CIRCLE_TOKEN"
  local WORKFLOW_JOBS_JSON="/tmp/aks/wf_$CIRCLE_WORKFLOW_ID.json"
  curl  -f -s --retry 3 "$WORKFLOW_JOBS_URL" > "$WORKFLOW_JOBS_JSON"
  STATUS=$(jq -r ".items[] | select(.name==\"$NAME_OF_JOB\") | .status | values" "$WORKFLOW_JOBS_JSON")
  NUMBER=$(jq -r ".items[] | select(.name==\"$NAME_OF_JOB\") | .job_number | values" "$WORKFLOW_JOBS_JSON")
  echo "$STATUS $NUMBER"
}

echo "Waiting for job(s): $JOB_LIST"
echo "Max wait: $MAX_WAIT_TIME"

for JOB_NAME in ${JOB_LIST//,/ }
do
  # Reset job status, job number and wait time
  JOB_STATUS=""
  JOB_NUMBER=""
  CURRENT_WAIT_TIME=0

  echo "Starting to check status of $JOB_NAME"
  while true; do
    read -r JOB_STATUS JOB_NUMBER < <(get_job_status "$JOB_NAME")
    if [ -z "$JOB_NUMBER" ]; then
      echo "No job with name $JOB_NAME can be found in this workflow"
      break
    fi
    if [[ "$JOB_STATUS" != "queued" && "$JOB_STATUS" != "running" && "$JOB_STATUS" != "not_running" ]]; then
      echo "Job $JOB_NAME has completed! Status: $JOB_STATUS"
      if [ "$JOB_STATUS" != "success" ] && $CHECK_FOR_FAILURE; then
        echo "The $JOB_NAME job failed, failing this job.";
        exit 1;
      fi
      break
    else
      echo "Looks like $JOB_NAME($JOB_NUMBER) is still not done. Status: $JOB_STATUS"
      echo "Going to sleep for $SLEEP_TIME"
      sleep "$SLEEP_TIME"
      CURRENT_WAIT_TIME=$(( CURRENT_WAIT_TIME + SLEEP_TIME ))
    fi

    if (( CURRENT_WAIT_TIME > MAX_WAIT_TIME )); then
      if $CONTINUE_ON_TIMEOUT; then
        echo "Max wait timout reached! Proceeding with further steps";
        break
      else
        echo "Max wait timout reached! Failing job!";
        exit 1;
      fi
    fi
  done
done
