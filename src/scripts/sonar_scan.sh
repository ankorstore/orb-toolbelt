#!/bin/bash
set -eo pipefail
export SONAR_TOKEN=${!SONAR_TOKEN_ENV}

if [ -z "$SONAR_TOKEN" ]; then
  echo "$SONAR_TOKEN_ENV env not set. Please set a valid SonarCloud Access Token in the env var $SONAR_TOKEN_ENV.";
  echo "Alternatively specify the name of an env containing a valid SonarCloud Access Token in the sonar-token parameter."
  exit 1;
fi

if [[ ! -x "$SCANNER_DIRECTORY/sonar-scanner-$VERSION-linux/bin/sonar-scanner" ]]; then
  echo "Scanner binary not found, downloading sonar-scanner-cli-$VERSION"
  mkdir -p "$SCANNER_DIRECTORY"
  curl -Ol "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$VERSION-linux.zip"
  unzip -qq -o "sonar-scanner-cli-$VERSION-linux.zip" -d "$SCANNER_DIRECTORY"
  chmod +x "$SCANNER_DIRECTORY/sonar-scanner-$VERSION-linux/bin/sonar-scanner"
  chmod +x "$SCANNER_DIRECTORY/sonar-scanner-$VERSION-linux/jre/bin/java"
fi

cd "$PROJECT_ROOT"
SONAR_SCANNER="$SCANNER_DIRECTORY/sonar-scanner-$VERSION-linux/bin/sonar-scanner"
if [ "$CIRCLE_BRANCH" = "$MAIN_BRANCH" ]; then
    $SONAR_SCANNER -Dsonar.branch.name="$MAIN_BRANCH"
else
    $SONAR_SCANNER
fi
