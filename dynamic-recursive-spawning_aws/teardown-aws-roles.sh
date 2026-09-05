#!/bin/bash
#
# Removes everything created by setup-aws-roles.sh: the deployer IAM user
# (access key + inline policy + user) and the Lambda execution role
# (detach managed policy + role). Does not touch anything else in your
# AWS account.
#
# Usage: ./teardown-aws-roles.sh

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
CREDS_FILE="$DIR/.workdir/aws-credentials.env"

ROLE_NAME="florca-ae-lambda-exec"
USER_NAME="florca-ae-deployer"
EXEC_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

log() { echo "==> $*"; }

if ! command -v aws >/dev/null; then
  echo "The AWS CLI is required." >&2
  exit 1
fi

if aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
  log "Deleting access keys for $USER_NAME"
  for key_id in $(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
    aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$key_id"
  done
  log "Deleting inline policy from $USER_NAME"
  aws iam delete-user-policy --user-name "$USER_NAME" --policy-name "florca-ae-deployer-permissions" 2>/dev/null || true
  log "Deleting IAM user $USER_NAME"
  aws iam delete-user --user-name "$USER_NAME"
else
  log "IAM user $USER_NAME not found, skipping"
fi

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  log "Detaching managed policy from $ROLE_NAME"
  aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$EXEC_POLICY_ARN" 2>/dev/null || true
  log "Deleting IAM role $ROLE_NAME"
  aws iam delete-role --role-name "$ROLE_NAME"
else
  log "IAM role $ROLE_NAME not found, skipping"
fi

rm -f "$CREDS_FILE"
log "Done."
