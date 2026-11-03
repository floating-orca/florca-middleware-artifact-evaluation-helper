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

# Each attempt's full output is kept in logs/attempt-N.log (the container
# runs with a TTY, so the logs contain \r line endings). Stale logs from a
# previous invocation are removed first.
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

run_suite() {
  docker run --rm -t --tmpfs /tmp florca-ae bats -r examples 2>&1 | tee "$LOG_DIR/attempt-$1.log"
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
