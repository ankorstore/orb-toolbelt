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

safeCurl() {
  local url=$1
  local temp_out
  local max_retries=${2:-3}
  local retry_count=0
  local timeout=1
  temp_out=$(mktemp)

  # loop until we get a successful response or reach the maximum number of retries
  while [[ $retry_count -lt $max_retries ]]; do
    local status_code

    if status_code="$(curl -L -f -s "$url" --write-out '%{http_code}' -o "$temp_out")"; then
      if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
        cat "$temp_out"
        rm "$temp_out"
        return 0
      fi
    fi
    retry_count=$(( retry_count + 1 ))
    timeout=$(( timeout * 2 ))
    sleep "$timeout"
  done
  rm "$temp_out"
  echo "Request to $url failed with status code $status_code after $max_retries attempts." >&2
  return 1
}

# fix unexpanded ~ in CIRCLE_WORKING_DIRECTORY
CIRCLE_WORKING_DIRECTORY="${CIRCLE_WORKING_DIRECTORY/#\~/$HOME}"

get_jobs_in_workflow() {
  local WORKFLOW_JOBS_URL="https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/job?circle-token=$CIRCLE_TOKEN"
  WORKFLOW_JOBS_JSON=$(safeCurl "$WORKFLOW_JOBS_URL")
}

get_artifacts_for_jobs() {
    local JOB_NAME=$1;
    if [[ $JOB_NAME != ^* ]]; then
      JOB_NAME="^$JOB_NAME\$"
    fi
    JOBS=$(jq -r --arg JOB_NAME "$JOB_NAME" '.items[] | select(.name | test($JOB_NAME)).job_number' <<<"$WORKFLOW_JOBS_JSON")
    while read -r JOB_NUM
    do
      get_artifacts_for_job
    done <<< "$JOBS"
}

get_artifacts_for_job() {
  local ARTIFACTS_URL="https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM/artifacts?circle-token=$CIRCLE_TOKEN"
  local ARTIFACTS_JSON
  ARTIFACTS_JSON=$(safeCurl "$ARTIFACTS_URL")
  local REQUIRED_ARTIFACTS
  REQUIRED_ARTIFACTS=$(jq -r --arg target_artifact_pattern "$TARGET_ARTIFACT_PATTERN" '.items[] | select(.path| test($target_artifact_pattern)) | "\(.url) \(.path)"' <<<"$ARTIFACTS_JSON")

  if [ -z "$REQUIRED_ARTIFACTS" ]; then
    echo "No Artifacts found."
    return 0;
  fi
  local tmp_config
  tmp_config=$(mktemp)
  while read -r ARTIFACT
  do
    # shellcheck disable=SC2086
    set -- $ARTIFACT
    local URL=$1
    shift
    local FILE_PATH="$*"

    if [ "$PRESERVE_PATHS" = 1 ]; then
      OUTPUT_PATH="$TARGET_PATH/$FILE_PATH"
      mkdir -p "$(dirname "$OUTPUT_PATH")"
    else
      OUTPUT_PATH="$TARGET_PATH/$(basename "$FILE_PATH")"
    fi
    echo "Downloading: $FILE_PATH"
    echo " => $OUTPUT_PATH"
    {
      echo "url $URL"
      echo "output \"$OUTPUT_PATH\""
    } >> "$tmp_config"
  done <<< "$REQUIRED_ARTIFACTS"
  curl -K "$tmp_config" -s -L --retry 3 --retry-all-errors --create-dirs -H "Circle-Token: $CIRCLE_TOKEN" --parallel --parallel-immediate --parallel-max "$PROCESSES"
  rm "$tmp_config"
}

if [ -n "$TARGET_PATH" ]; then
  TARGET_PATH="$CIRCLE_WORKING_DIRECTORY/$TARGET_PATH"
  mkdir -p "$TARGET_PATH"
else
  TARGET_PATH="$CIRCLE_WORKING_DIRECTORY"
fi

echo "Downloading artifact(s) from job(s): $JOB_LIST"
echo "Downloading artifact(s) to $TARGET_PATH"
get_jobs_in_workflow
for JOB_NAME in ${JOB_LIST//,/ }
do
  get_artifacts_for_jobs "$JOB_NAME"
done
