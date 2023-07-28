#!/bin/bash
set -e

if [ ! -d "$TIMINGS_DIR" ]; then
  echo "No test timings found at $TIMINGS_DIR"
else
  echo "Test timings found:"
  cat "$TIMINGS_DIR/source.txt"
  echo "Junit XML files:"
  find "$TIMINGS_DIR" -type f -name "*.xml"
fi
