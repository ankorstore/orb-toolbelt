#!/bin/bash
mkdir "/tmp/$TARBALL_NAME"

echo "Creating tarball of $ARTIFACT_PATH"
echo " => /tmp/$TARBALL_NAME/$TARBALL_NAME-$CIRCLE_NODE_INDEX.tar.gz"

ls -lah "$ARTIFACT_PATH"

tar -czf "/tmp/$TARBALL_NAME/$TARBALL_NAME-$CIRCLE_NODE_INDEX.tar.gz" "$ARTIFACT_PATH"
