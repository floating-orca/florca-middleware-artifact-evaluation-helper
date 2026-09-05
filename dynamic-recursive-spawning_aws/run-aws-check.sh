#!/bin/bash
#
# PREREQUISITES: ../basic-functional-tests_docker/build.sh (builds the
# florca-ae image this script uses) and ./setup-aws-roles.sh
# (creates the AWS credentials this script reads).
#
# Deploys and runs the paper's Web-Crawler experiment (Recursive Dynamic
# Spawning, examples/webcrawler-video).
#
# For each page, a Lambda function fetches it and extracts links (and
# any video references); newly discovered links are reported and deduplicated via sendMsg and then crawled the same
# way via further Lambda invocations, until 
# no new pages remain. Crawls the 100-page website at
# webcrawler-demopage/, published via this repo's GitHub Pages.
#
# Usage: ./run-aws-check.sh

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
CREDS_FILE="$DIR/.workdir/aws-credentials.env"
FIXTURE_URL="https://floating-orca.github.io/florca-middleware-artifact-evaluation-helper/aws/webcrawler-demopage/"
DEPLOYMENT_NAME="florca-ae-webcrawler"

if [ ! -f "$CREDS_FILE" ]; then
  echo "No credentials found at $CREDS_FILE. Run ./setup-aws-roles.sh first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CREDS_FILE"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_ROLE

if ! docker image inspect florca-ae >/dev/null 2>&1; then
  echo "The florca-ae image is not built yet. Run ../basic-functional-tests_docker/build.sh first." >&2
  exit 1
fi

echo "==> Deploying and running examples/webcrawler-video (100-page graph fixture at $FIXTURE_URL)"
docker run --rm --tmpfs /tmp \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION -e AWS_ROLE \
  florca-ae bash -c "
    set -Eeuo pipefail
    florca deploy --workflow-directory examples/webcrawler-video '$DEPLOYMENT_NAME'
    output=\"\$(florca run --deployment-name '$DEPLOYMENT_NAME' --wait --input '{\"url\":\"$FIXTURE_URL\"}')\"
    echo \"\$output\"
    florca delete '$DEPLOYMENT_NAME' || true
    echo \"\$output\" | grep -q 'Success: true'
  "

echo "==> AWS functional check PASSED"
