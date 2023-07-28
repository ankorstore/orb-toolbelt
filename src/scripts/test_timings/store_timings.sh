#!/bin/bash
echo "Storing test report(s) for timing data:"
echo "$TEST_REPORT_DIR => $TIMINGS_DIR"

if [ ! -d "$TIMINGS_DIR" ]; then
  mkdir -p "$TIMINGS_DIR"
  find "$TEST_REPORT_DIR" -type f -name "*.xml" -exec cp  "{}" "$TIMINGS_DIR" \;
  {
    echo "Timings Key: $TIMINGS_KEY"
    echo "Commit: $CIRCLE_SHA1"
    echo "Branch: $CIRCLE_BRANCH"
    echo "Job Name: $CIRCLE_JOB"
    echo "Job Id: $CIRCLE_BUILD_NUM"
    echo "Job URL: $CIRCLE_BUILD_URL"
    echo "Node Index: $CIRCLE_NODE_INDEX"
    echo "Node Total: $CIRCLE_NODE_TOTAL"
  } > "$TIMINGS_DIR/source.txt"
  cat "$TIMINGS_DIR/source.txt"
  echo "Junit XML files:"
  find "$TIMINGS_DIR" -type f -name "*.xml"
fi
