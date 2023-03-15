#!/bin/bash
# Get workflows for the current pipeline and extract the previous execution of the current workflows name if there is one
get_workflows_in_pipeline() {
  local WORKFLOW_ENDPOINT="https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 "$WORKFLOW_ENDPOINT" > /tmp/aks/current_wf.json
  local CIRCLE_WORKFLOW_NAME
  CIRCLE_WORKFLOW_NAME=$(jq -r '.name ' /tmp/aks/current_wf.json)

  local WORKFLOWS_IN_PIPELINE_ENDPOINT="https://circleci.com/api/v2/pipeline/$CIRCLE_PIPELINE_ID/workflow?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 "$WORKFLOWS_IN_PIPELINE_ENDPOINT" > /tmp/aks/pipeline_wf.json
  PREVIOUS_WORKFLOW_ID=$(jq -r --arg current_workflow_id "$CIRCLE_WORKFLOW_ID" --arg current_workflow_name "$CIRCLE_WORKFLOW_NAME" '.items[] | select(.name == $current_workflow_name and .id != $current_workflow_id).id | values' /tmp/aks/pipeline_wf.json | head -n 1)
}

# Get jobs from the previous workflow and extract the job number for this current jobs previous build.
get_job_from_previous_workflow() {
  local JOBS_IN_WORKFLOW_ENDPOINT="https://circleci.com/api/v2/workflow/$PREVIOUS_WORKFLOW_ID/job?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 "$JOBS_IN_WORKFLOW_ENDPOINT" > /tmp/aks/previous_wf_jobs.json
  JOB_NUM=$(jq -r --arg current_job_name "$CIRCLE_JOB" '.items[] | select(.name | test($current_job_name)).job_number | values' /tmp/aks/previous_wf_jobs.json)
}

# Download all artifacts from a job
get_artifacts_for_job() {
  local ARTIFACTS_URL="https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$JOB_NUM/artifacts?circle-token=$CIRCLE_TOKEN"
  curl -f -s --retry 3 "$ARTIFACTS_URL" > /tmp/aks/artifacts.json
  local REQUIRED_ARTIFACTS
  REQUIRED_ARTIFACTS=$(jq -r --argjson node_index "${CIRCLE_NODE_INDEX:-0}" '.items[] | select(.node_index == $node_index) | "\(.url) \(.path)"' /tmp/aks/artifacts.json)

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
    echo "Downloading: $FILE_PATH"
    curl -s -L --retry 3 --create-dirs -H "Circle-Token: $CIRCLE_TOKEN" -o "$FILE_PATH" "$URL"
  done <<< "$REQUIRED_ARTIFACTS"
}

# Has this job previously succeeded in this pipeline?
PASS_RECORD=$(echo "$CIRCLE_JOB-$CIRCLE_NODE_INDEX-$CIRCLE_PIPELINE_ID" | sed -e "s/[^[:alnum:]]/-/g" | tr -s "-" | tr "[:upper:]" "[:lower:]")
if [ -f ".pass/$PASS_RECORD" ]; then

  # Check dependencies
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

  echo "This job has succeeded previously in this workflow restoring artifacts..."
  # export this to env for the later skip script
  echo 'export PASS_FAST="true"' >> "$BASH_ENV"
  mkdir -p /tmp/aks

  get_workflows_in_pipeline

  if [ -n "$PREVIOUS_WORKFLOW_ID" ]; then
    echo "Getting job from previous workflow: $PREVIOUS_WORKFLOW_ID"
    get_job_from_previous_workflow
    if [ -n "$JOB_NUM" ]; then
      echo "Getting artifacts from previous job: $JOB_NUM"
      # fix unexpanded ~ in CIRCLE_WORKING_DIRECTORY
      CIRCLE_WORKING_DIRECTORY="${CIRCLE_WORKING_DIRECTORY/#\~/$HOME}"
      cd "$CIRCLE_WORKING_DIRECTORY" || exit 1
      get_artifacts_for_job
    else
       echo "No previous execution of this job found in the workflow $PREVIOUS_WORKFLOW_ID"
    fi
  else
    echo "No previous execution of this workflow found in this pipeline."
  fi
else
  echo "Job has not previously succeeded, no artifacts to restore"
fi
# cleanup any pass records
rm -rf .pass
