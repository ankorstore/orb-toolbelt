#!/bin/bash
if [ -n "$PASS_FAST" ]; then
  echo "This job has succeeded previously in this pipeline skipping..."
  circleci-agent step halt
fi