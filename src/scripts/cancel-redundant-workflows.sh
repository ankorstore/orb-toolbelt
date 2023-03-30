#!/bin/bash

if [ -z "$BASH" ]; then
  echo "Bash not installed. Aborting."
  exit 1
fi
hash curl 2>/dev/null || { echo >&2 "curl is not installed. Aborting."; exit 1; }
if [ -z "$CIRCLE_TOKEN" ]; then
  echo "CIRCLE_TOKEN env not set. Please set a valid CircleCi API Token in the env var CIRCLE_TOKEN";
  exit 1;
fi

mkdir -p /tmp/aks

# Get the name of the workflow and the related pipeline number
CURRENT_WORKFLOW_URL="https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}?circle-token=$CIRCLE_TOKEN"
curl -f -s --retry 3 --retry-all-errors "$CURRENT_WORKFLOW_URL" > /tmp/aks/current_wf.json
CURRENT_WORKFLOW_NAME="$(jq -r '.name' /tmp/aks/current_wf.json)"
CURRENT_PIPELINE_NUM="$(jq -r '.pipeline_number' /tmp/aks/current_wf.json)"

WORKFLOW_NAME=${TARGET_WORKFLOW_NAME:-$CURRENT_WORKFLOW_NAME}
if [[ $WORKFLOW_NAME != ^* ]]; then
      WORKFLOW_NAME="^$WORKFLOW_NAME\$"
fi

# Get the IDs of pipelines created for the same branch. (Only consider pipelines that have a pipeline number smaller than the current pipeline)
PIPELINES_URL="https://circleci.com/api/v2/project/gh/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pipeline?circle-token=$CIRCLE_TOKEN&branch=$CIRCLE_BRANCH"
curl -f -s --retry 3 --retry-all-errors "$PIPELINES_URL" >> /tmp/aks/pipelines.json
PIPELINE_IDS=$(jq -r --argjson CURRENT_PIPELINE_NUM "$CURRENT_PIPELINE_NUM" '.items[]|select(.state == "created")|select(.number < $CURRENT_PIPELINE_NUM)|.id | values' /tmp/aks/pipelines.json)

## Get the IDs of currently running/on_hold workflows that have the same name as the current workflow, in all previously created pipelines.
if [ -n "$PIPELINE_IDS" ]; then
  for PIPELINE_ID in $PIPELINE_IDS
  do
    curl -f -s --retry 3 --retry-all-errors "https://circleci.com/api/v2/pipeline/${PIPELINE_ID}/workflow?circle-token=$CIRCLE_TOKEN" | jq -r --arg workflow_name "${WORKFLOW_NAME}" '.items[] | select(.status == "on_hold" or .status == "running") | select(.name | test($workflow_name)) | .id | values' >> /tmp/aks/wf_to_cancel
  done
fi

## Cancel any currently running/on_hold workflow with the same name
if [ -s /tmp/aks/wf_to_cancel ]; then
  echo "Cancelling the following redundant \`$WORKFLOW_NAME\` workflow(s):"
  cat /tmp/aks/wf_to_cancel
  echo ""
  while read -r WORKFLOW_ID;
    do
      curl -f -s -o /dev/null --retry 3 --retry-all-errors --header "Circle-Token: $CIRCLE_TOKEN" --request POST "https://circleci.com/api/v2/workflow/$WORKFLOW_ID/cancel"
      echo "Cancelled: $WORKFLOW_ID"
    done < /tmp/aks/wf_to_cancel
  else
    echo "Nothing to cancel"
fi
