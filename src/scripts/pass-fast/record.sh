#!/bin/bash
mkdir .pass
PASS_RECORD=$(echo "$CIRCLE_JOB-$CIRCLE_NODE_INDEX-$CIRCLE_PIPELINE_ID" | sed -e "s/[^[:alnum:]]/-/g" | tr -s "-" | tr "[:upper:]" "[:lower:]")
echo "Success!" > ".pass/$PASS_RECORD"