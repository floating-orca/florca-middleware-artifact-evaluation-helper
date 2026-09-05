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

echo "==> Running the example-workflow suite (examples/*/test.bats)"
if ! docker run --rm -t --tmpfs /tmp florca-ae bats -r examples; then
  echo "==> Suite failed, retrying once" >&2
  docker run --rm -t --tmpfs /tmp florca-ae bats -r examples
fi
echo "==> Example suite PASSED"
