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

echo "$WHY"
curl -f -s --retry 3 --retry-all-errors -X POST --header "Content-Type: application/json" "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/cancel?circle-token=$CIRCLE_TOKEN"
