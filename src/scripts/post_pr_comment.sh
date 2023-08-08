#!/bin/bash

set -eo pipefail

if [ -n "$COMMENT_FILE" ] && [ -f "$COMMENT_FILE" ]; then
  echo "COMMENT_FILE: $COMMENT_FILE"
  COMMENT=$(cat "$COMMENT_FILE")
fi

if [ -z "$COMMENT" ]; then
  echo "No comment provided, skipping comment"
  exit 0
fi

if ! (command -v jq >/dev/null 2>&1); then
  echo "This command requires jq to be installed"
  exit 1
fi

if [ -z "$CIRCLE_BRANCH" ]; then
  echo "No Branch detected, tag pipelines will not have a PR."
  exit 0
fi

# Get the associated PR number
PR_NUMBER=$(gh pr list --head "$CIRCLE_BRANCH" --json number -q '.[] | .number')

if [ -z "$PR_NUMBER" ]; then
  echo "No associated PR"
  exit "$FAIL_WITHOUT_PR"
fi

echo "PR_NUMBER: $PR_NUMBER"
FULL_COMMENT_TAG=""
COMMENT_ID=""

echo "$COMMENT" > body.md

if [ -n "$COMMENT_TAG" ]; then
  echo "COMMENT_TAG: $COMMENT_TAG"
  FULL_COMMENT_TAG="<!-- toolbelt/post_pr_comment ${COMMENT_TAG} -->"
  COMMENT_ID=$(gh api "/repos/{owner}/{repo}/issues/$PR_NUMBER/comments" --jq ".[] | select(.body | contains(\"$FULL_COMMENT_TAG\")) | .id")
  printf "\n%s" "$FULL_COMMENT_TAG" >> body.md
fi

if [ -z "${COMMENT_ID}" ]; then
  if [ -n "$COMMENT_TAG" ]; then
    echo "No comment tagged \`$COMMENT_TAG\` found, creating new comment"
  else
    echo "Creating new comment"
  fi
  gh pr comment --body-file body.md
else
  echo "Updating comment"
  echo "COMMENT_ID: $COMMENT_ID"
  gh api "/repos/{owner}/{repo}/issues/comments/$COMMENT_ID" -X PATCH -f body="$(cat body.md)"
fi
