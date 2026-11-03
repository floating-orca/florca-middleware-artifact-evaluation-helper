#!/bin/bash
#
# Functional-badge check for floating-orca/florca v0.8.1
# (Middleware 2026, DOI 10.5281/zenodo.19712026).
#
# Boots a single, self-contained container (deployer + engine + Caddy +
# Postgres) and deploys/runs the repository's example workflows
# (examples/*/test.bats, 20 examples, 26 test cases), checking each for
# a successful result. No host networking or GitHub Container Registry
# login is required.
#
# Usage:
#   ./build.sh                # build the florca-ae image once
#   ./run-functional-check.sh # run the example-workflow suite

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
LOG_DIR="$DIR/logs"

# Each attempt's full output is kept in logs/attempt-N.log. The container runs
# with a TTY (for bats' live progress display); in the saved log, the progress
# redraws and terminal escape codes are removed so that it reads as plain text.
# Stale logs from a previous invocation are removed first.
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

clean_log() {
  sed -E 's/\x1b\[1G/\n/g' "$1" \
    | sed -E '/\x1b\[75G/d' \
    | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\r//g' \
    | sed -E '/^$/d' > "$2"
}

run_suite() {
  local status=0
  # pipefail (set above) makes the pipeline's status that of docker, not tee
  docker run --rm -t --tmpfs /tmp florca-ae bats -r examples 2>&1 | tee "$LOG_DIR/.raw-$1.log" || status=$?
  clean_log "$LOG_DIR/.raw-$1.log" "$LOG_DIR/attempt-$1.log"
  rm -f "$LOG_DIR/.raw-$1.log"
  return "$status"
}

echo "==> Running the example-workflow suite (examples/*/test.bats), attempt 1"
if run_suite 1; then
  echo "==> Example suite PASSED (first attempt)"
  exit 0
fi

echo "==> Attempt 1 failed (log: $LOG_DIR/attempt-1.log), retrying once" >&2
if run_suite 2; then
  echo "==> Example suite PASSED ON RETRY (attempt 1 failed; see $LOG_DIR/attempt-1.log)"
  exit 0
fi

echo "==> Example suite FAILED (both attempts; see $LOG_DIR/)" >&2
exit 1
