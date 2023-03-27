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

# fix unexpanded ~ in CIRCLE_WORKING_DIRECTORY
CIRCLE_WORKING_DIRECTORY="${CIRCLE_WORKING_DIRECTORY/#\~/$HOME}"

mkdir -p /tmp/aks
WORKFLOW_JOBS_JSON=/tmp/aks/current_wf_jobs.json

get_jobs_in_workflow() {
  local WORKFLOW_JOBS_URL="https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/job?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 --retry-all-errors "$WORKFLOW_JOBS_URL" > "$WORKFLOW_JOBS_JSON"
}

get_artifacts_for_jobs() {
    local JOB_NAME=$1;
    if [[ $JOB_NAME != ^* ]]; then
      JOB_NAME="^$JOB_NAME\$"
    fi
    JOBS=$(jq -r --arg JOB_NAME "$JOB_NAME" '.items[] | select(.name | test($JOB_NAME)).job_number' "$WORKFLOW_JOBS_JSON")
    while read -r JOB_NUM
    do
      get_artifacts_for_job
    done <<< "$JOBS"
}

get_artifacts_for_job() {
  local ARTIFACTS_URL="https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM/artifacts?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 --retry-all-errors "$ARTIFACTS_URL" > /tmp/aks/artifacts.json
  local REQUIRED_ARTIFACTS
  REQUIRED_ARTIFACTS=$(jq -r --arg target_artifact_pattern "$TARGET_ARTIFACT_PATTERN" '.items[] | select(.path| test($target_artifact_pattern)) | "\(.url) \(.path)"' /tmp/aks/artifacts.json)

  if [ -z "$REQUIRED_ARTIFACTS" ]; then
    echo "No Artifacts found."
    return 0;
  fi

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
    curl -s -L --retry 3 --retry-all-errors --create-dirs -H "Circle-Token: $CIRCLE_TOKEN" -o "$OUTPUT_PATH" "$URL"
  done <<< "$REQUIRED_ARTIFACTS"
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
