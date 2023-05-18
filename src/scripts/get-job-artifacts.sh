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
    local job_name=$1;
    if [[ $job_name != ^* ]]; then
      job_name="^$job_name\$"
    fi
    echo "Getting artifacts for jobs matching \`$job_name\`"
    JOBS=$(jq -r --arg job_name "$job_name" '.items[] | select(.name | test($job_name)) | "\(.job_number) \(.name)"' <<<"$WORKFLOW_JOBS_JSON")
    if [ -z "$JOBS" ]; then
      echo "No jobs found matching \`$job_name\`"
      return 0;
    fi
    while read -r JOB_NUM JOB_NAME
    do
      get_artifacts_for_job "$JOB_NUM" "$JOB_NAME"
    done <<< "$JOBS"
}

get_artifacts_for_job() {
  local JOB_NUM=$1
  local JOB_NAME=$2
  local ARTIFACTS_URL="https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM/artifacts?circle-token=$CIRCLE_TOKEN"
  local ARTIFACTS_JSON
  ARTIFACTS_JSON=$(safeCurl "$ARTIFACTS_URL")
  local REQUIRED_ARTIFACTS
  REQUIRED_ARTIFACTS=$(jq -r --arg target_artifact_pattern "$TARGET_ARTIFACT_PATTERN" '.items[] | select(.path| test($target_artifact_pattern)) | "\(.url) \(.path)"' <<<"$ARTIFACTS_JSON")
  echo "Getting artifacts for job \`$JOB_NAME\` ($JOB_NUM)"
  if [ -z "$REQUIRED_ARTIFACTS" ]; then
    echo "No Artifacts found."
    return 0;
  fi
  local tmp_config
  tmp_config=$(mktemp)
  local tmp_zipped
  tmp_zipped=$(mktemp)
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
    if [[ "$FILE_PATH" == *.tar.gz ]]; then
      echo "$OUTPUT_PATH" >> "$tmp_zipped"
    fi
  done <<< "$REQUIRED_ARTIFACTS"
  curl -K "$tmp_config" -s -L --retry 3 --retry-all-errors --create-dirs -H "Circle-Token: $CIRCLE_TOKEN" --parallel --parallel-immediate --parallel-max "$PROCESSES"
  rm "$tmp_config"
  if [ "$UNZIP" = 1 ] && [ -s "$tmp_zipped" ]; then
    echo "Unzipping files:"
    cat "$tmp_zipped"
    xargs -n 1 tar -xzf < "$tmp_zipped"
    xargs -n 1 rm < "$tmp_zipped"
  fi
}

if [ -n "$TARGET_PATH" ]; then
  TARGET_PATH="$CIRCLE_WORKING_DIRECTORY/$TARGET_PATH"
  mkdir -p "$TARGET_PATH"
else
  TARGET_PATH="$CIRCLE_WORKING_DIRECTORY"
fi

echo "Downloading artifact(s) matching \`$TARGET_ARTIFACT_PATTERN\` from job(s): $JOB_LIST"
echo "Downloading artifact(s) to $TARGET_PATH"
get_jobs_in_workflow
if [[ "$JOB_LIST" != ^* ]]; then
  for job_name in ${JOB_LIST//,/ }
  do
    get_artifacts_for_jobs "$job_name"
  done
else
  get_artifacts_for_jobs "$JOB_LIST"
fi
