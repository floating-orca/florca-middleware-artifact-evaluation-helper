#!/bin/bash
#
# READ THIS SCRIPT BEFORE RUNNING IT. It creates exactly two things in
# YOUR OWN AWS account, using YOUR OWN already-configured `aws` CLI
# credentials (make sure you have the necessary permissions):
#
#   1. An IAM role "florca-ae-lambda-exec" that AWS Lambda can assume,
#      with only the AWS-managed AWSLambdaBasicExecutionRole policy
#      attached (write CloudWatch Logs, nothing else). This is the
#      execution role florca attaches to deployed functions (the AWS_ROLE
#      setting documented in the florca user guide).
#
#   2. An IAM user "florca-ae-deployer" with a custom, narrowly-scoped
#      inline policy (see policies/deployer-permissions-policy.json) that
#      only allows managing Lambda functions named "florca-ae-*" (plus the
#      unavoidably account-wide lambda:ListFunctions, and iam:PassRole
#      scoped to the exec role above), and a new access key for it. This
#      is what the deployer/engine/driver use to call the AWS Lambda API,
#      in place of the docs' broader `AWSLambda_FullAccess`.
#
# Nothing else is touched. Run ./teardown-aws-roles.sh afterwards to
# remove both.
#
# Usage: ./setup-aws-roles.sh [--yes]
#   --yes   skip the confirmation prompt (for scripted use)

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
WORK_DIR="$DIR/.workdir"
CREDS_FILE="$WORK_DIR/aws-credentials.env"

ROLE_NAME="florca-ae-lambda-exec"
USER_NAME="florca-ae-deployer"
EXEC_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

confirm=""
if [ "${1:-}" = "--yes" ]; then
  confirm="yes"
fi

log() { echo "==> $*"; }

if ! command -v aws >/dev/null; then
  echo "The AWS CLI is required. See https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" >&2
  exit 1
fi

if ! docker image inspect florca-ae >/dev/null 2>&1; then
  echo "The florca-ae image is not built yet. Run ../basic-functional-tests_docker/build.sh first." >&2
  exit 1
fi

identity="$(aws sts get-caller-identity 2>&1)" || {
  echo "aws sts get-caller-identity failed. Configure credentials first (e.g. 'aws configure')." >&2
  echo "$identity" >&2
  exit 1
}
echo "$identity"

region="$(aws configure get region || true)"
if [ -z "$region" ]; then
  read -rp "No default AWS region configured. Enter one to use (e.g. eu-central-1): " region
fi

echo
echo "This will create IAM role '${ROLE_NAME}' and IAM user '${USER_NAME}'"
echo "(plus a new access key for that user) in the AWS account/region shown"
echo "above. Region for the demo deployment: ${region}."
echo
if [ -z "$confirm" ]; then
  read -rp "Have you read this script and want to proceed? [y/N] " reply
  case "$reply" in
    y|Y) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

mkdir -p "$WORK_DIR"
chmod 700 "$WORK_DIR"

# ---------------------------------------------------------------------------
# 1. Lambda execution role
# ---------------------------------------------------------------------------

if role_arn="$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null)"; then
  log "IAM role $ROLE_NAME already exists, reusing it ($role_arn)"
else
  log "Creating IAM role $ROLE_NAME"
  role_arn="$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$DIR/policies/lambda-exec-trust-policy.json" \
    --query 'Role.Arn' --output text)"
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$EXEC_POLICY_ARN"
  log "Waiting for IAM role propagation"
  sleep 10
fi

# ---------------------------------------------------------------------------
# 2. Deployer IAM user, scoped policy, and access key
# ---------------------------------------------------------------------------

if aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
  log "IAM user $USER_NAME already exists, reusing it"
else
  log "Creating IAM user $USER_NAME"
  aws iam create-user --user-name "$USER_NAME" >/dev/null
fi

policy_doc="$WORK_DIR/deployer-permissions-policy.rendered.json"
sed "s|__EXEC_ROLE_ARN__|${role_arn}|" "$DIR/policies/deployer-permissions-policy.json" > "$policy_doc"

log "Attaching the scoped inline policy to $USER_NAME"
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "florca-ae-deployer-permissions" \
  --policy-document "file://$policy_doc"

if [ -f "$CREDS_FILE" ]; then
  log "Reusing existing access key from a previous run ($CREDS_FILE)"
else
  log "Creating an access key for $USER_NAME"
  key_json="$(aws iam create-access-key --user-name "$USER_NAME")"
  access_key_id="$(echo "$key_json" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4)"
  secret_access_key="$(echo "$key_json" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)"

  cat > "$CREDS_FILE" <<EOF
# Created by setup-aws-roles.sh. Contains a live AWS access key - do not
# commit this file. Removed by teardown-aws-roles.sh.
AWS_ACCESS_KEY_ID=${access_key_id}
AWS_SECRET_ACCESS_KEY=${secret_access_key}
AWS_REGION=${region}
AWS_ROLE=${role_arn}
EOF
  chmod 600 "$CREDS_FILE"
fi

echo
log "Done. Credentials written to $CREDS_FILE (not committed to git)."
log "Run ./run-aws-check.sh next, and ./teardown-aws-roles.sh when finished."
