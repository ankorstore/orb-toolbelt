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
curl -f -s -o ./hack/orb.bats https://raw.githubusercontent.com/CircleCI-Public/orb-tools-orb/master/src/scripts/review.bats
ORB_VAL_MAX_COMMAND_LENGTH=120 bats ./hack/orb.bats
