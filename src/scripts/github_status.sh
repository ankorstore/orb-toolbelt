#!/bin/bash
set -euo pipefail
[ -n "$CONTEXT" ] || CONTEXT="${GITHUB_STATUS_CONTEXT:-circleci/$CIRCLE_JOB}"
[ -n "$DESCRIPTION" ] || DESCRIPTION="${GITHUB_STATUS_DESCRIPTION:-$CONTEXT}"
[ -n "$TARGET" ] || TARGET="${GITHUB_STATUS_TARGET:-$CIRCLE_BUILD_URL}"

if [ "$TARGET" = "job" ]; then
  TARGET="$CIRCLE_BUILD_URL"
fi
if [ "$TARGET" = "workflow" ]; then
  TARGET="https://app.circleci.com/pipelines/workflows/$CIRCLE_WORKFLOW_ID"
fi

# Export the latest values for CONTEXT, DESCRIPTION and TARGET so later calls
# do not need to set them explicitly again.
{
  echo "export GITHUB_STATUS_CONTEXT='$CONTEXT'"
  echo "export GITHUB_STATUS_DESCRIPTION='$DESCRIPTION'"
  echo "export GITHUB_STATUS_TARGET='$TARGET'"
 } >> "$BASH_ENV"

URL="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/statuses/$CIRCLE_SHA1"
# Compose the body.
BODY='
{
  "state": "'"$STATE"'",
  "target_url": "'"$TARGET"'",
  "description": "'"$DESCRIPTION"'",
  "context": "'"$CONTEXT"'"
}
'
echo "$BODY" | curl -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" -XPOST -d@- "$URL"
