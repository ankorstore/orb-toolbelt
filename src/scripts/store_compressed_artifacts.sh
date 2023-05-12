#!/bin/bash
mkdir "/tmp/$TARBALL_NAME"
tar -czf "/tmp/$TARBALL_NAME/$TARBALL_NAME-$CIRCLE_NODE_INDEX.tar.gz" "$ARTIFACT_PATH"
