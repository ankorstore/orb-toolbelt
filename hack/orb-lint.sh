#!/bin/bash
if ! command -v bats >/dev/null; then
	echo 'The "bats-core" automation framework must be installed.'
	echo 'See https://bats-core.readthedocs.io/en/stable/installation.html'
	exit 1
fi
if ! command -v yq >/dev/null; then
	echo 'The "yq" package must be installed.'
	exit 1
fi
# use modified local rules until https://github.com/CircleCI-Public/orb-tools-orb/pull/196 this issue is fixed
#curl -f -s -o ./hack/orb.bats https://raw.githubusercontent.com/CircleCI-Public/orb-tools-orb/master/src/scripts/review.bats
PARAM_RC_EXCLUDE=RC006 PARAM_MAX_COMMAND_LENGTH=120 bats ./hack/orb.bats
