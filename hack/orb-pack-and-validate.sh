#!/bin/bash
if ! command -v circleci &> /dev/null
then
    echo "Circleci CLI could not be found. Install the latest CLI version https://circleci.com/docs/2.0/local-cli/#installation"
    exit 1
fi

circleci orb pack --skip-update-check src > orb.yml
circleci orb validate --skip-update-check orb.yml
