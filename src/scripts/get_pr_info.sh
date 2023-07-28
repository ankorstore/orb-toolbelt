#!/bin/bash

set -eo pipefail

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

slugify() {
  printf "%s" "$1" | sed -e "s/[^[:alnum:]]/-/g" | tr -s "-" | tr "[:upper:]" "[:lower:]"
}

escape_double_quotes() {
  local STR="$1"
  echo "${STR//"\""/"\\\""}"
}

echo "PR_NUMBER: $PR_NUMBER"

API_GITHUB="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"
PR_REQUEST_URL="$API_GITHUB/pulls/$PR_NUMBER"
PR_RESPONSE=$(curl -s -f --retry 3 -H "Authorization: token $GITHUB_TOKEN" "$PR_REQUEST_URL")

PR_TITLE=$(echo "$PR_RESPONSE" | jq -re '.title')
echo "PR_TITLE: $PR_TITLE"

CIRCLE_BRANCH_SLUG="$(slugify "$CIRCLE_BRANCH")"
echo "CIRCLE_BRANCH_SLUG: $CIRCLE_BRANCH_SLUG"

PR_BASE_BRANCH=$(echo "$PR_RESPONSE" | jq -re '.base.ref')
echo "PR_BASE_BRANCH: $PR_BASE_BRANCH"

PR_BASE_BRANCH_SLUG="$(slugify "$PR_BASE_BRANCH")"
echo "PR_BASE_BRANCH_SLUG: $PR_BASE_BRANCH_SLUG"

PR_AUTHOR_USERNAME=$(echo "$PR_RESPONSE" | jq -re '.user.login')
echo "PR_AUTHOR_USERNAME: $PR_AUTHOR_USERNAME"

PR_LABELS=$(echo "$PR_RESPONSE" | jq -r '.labels | map(.name) | join(",")')
echo "PR_LABELS: $PR_LABELS"

cat << EOF >> "$BASH_ENV"
GITHUB_PR_NUMBER=$PR_NUMBER
export GITHUB_PR_NUMBER
GITHUB_PR_TITLE="$(escape_double_quotes "$PR_TITLE")"
export GITHUB_PR_TITLE
CIRCLE_BRANCH_SLUG="$(escape_double_quotes "$CIRCLE_BRANCH_SLUG")"
export CIRCLE_BRANCH_SLUG
GITHUB_PR_BASE_BRANCH="$(escape_double_quotes "$PR_BASE_BRANCH")"
export GITHUB_PR_BASE_BRANCH
GITHUB_PR_BASE_BRANCH_SLUG="$(escape_double_quotes "$PR_BASE_BRANCH_SLUG")"
export GITHUB_PR_BASE_BRANCH_SLUG
GITHUB_PR_AUTHOR_USERNAME="$(escape_double_quotes "$PR_AUTHOR_USERNAME")"
export GITHUB_PR_AUTHOR_USERNAME
GITHUB_PR_LABELS="$(escape_double_quotes "$PR_LABELS")"
export GITHUB_PR_LABELS
EOF

if [ "$GET_PR_AUTHOR" == 1 ]; then
  # We need to use the email address associated with the merge_commit_sha since
  # CIRCLE_SHA1 may have been authored by someone who is not the PR author.
  # Sadly, PR_RESPONSE doesn't include the email associated with the merge_commit_sha.
  # So we have to get that from the commit information.

  PR_MERGE_COMMIT_SHA=$(echo "$PR_RESPONSE" | jq -re '.merge_commit_sha')
  COMMIT_REQUEST_URL="$API_GITHUB/commits/$PR_MERGE_COMMIT_SHA"
  COMMIT_RESPONSE=$(curl -s -f --retry 3 -H "Authorization: token $GITHUB_TOKEN" "$COMMIT_REQUEST_URL")

  PR_AUTHOR_EMAIL=$(echo "$COMMIT_RESPONSE" | jq -re '.commit.author.email')
  echo "PR_AUTHOR_EMAIL: $PR_AUTHOR_EMAIL"

  PR_AUTHOR_NAME=$(echo "$COMMIT_RESPONSE" | jq -re '.commit.author.name')
  echo "PR_AUTHOR_NAME: $PR_AUTHOR_NAME"

  cat << EOF >> "$BASH_ENV"
GITHUB_PR_AUTHOR_EMAIL="$(escape_double_quotes "$GITHUB_PR_AUTHOR_EMAIL")"
export GITHUB_PR_AUTHOR_EMAIL
GITHUB_PR_AUTHOR_NAME="$(escape_double_quotes "$GITHUB_PR_AUTHOR_NAME")"
export GITHUB_PR_AUTHOR_NAME
EOF
fi

if [ "$GET_COMMIT_MESSAGE" = 1 ]; then
  COMMIT_REQUEST_URL="$API_GITHUB/commits/$CIRCLE_SHA1"
  COMMIT_RESPONSE=$(curl -s -f --retry 3 -H "Authorization: token $GITHUB_TOKEN" "$COMMIT_REQUEST_URL")

  PR_COMMIT_MESSAGE=$(echo "$COMMIT_RESPONSE" | jq -re '.commit.message')
  echo "PR_COMMIT_MESSAGE: $PR_COMMIT_MESSAGE"

  cat << EOF >> "$BASH_ENV"
GITHUB_PR_COMMIT_MESSAGE="$(escape_double_quotes "$GITHUB_PR_COMMIT_MESSAGE")"
export GITHUB_PR_COMMIT_MESSAGE
EOF
fi
