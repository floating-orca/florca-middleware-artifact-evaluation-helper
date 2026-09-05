#!/bin/bash
#
# Tears down everything created by run.sh: the run container itself and
# the kind cluster it created on the host Docker daemon. Does not require
# `kind` to be installed on the host - it only lived inside the container
# built by build.sh - so this removes kind's containers/network directly
# by the labels kind itself attaches to them.

set -Eeuo pipefail

CONTAINER_NAME="florca-ae-kind-run"

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME"
fi

kind_containers="$(docker ps -a --filter 'label=io.x-k8s.kind.cluster' --format '{{.Names}}')"
if [ -n "$kind_containers" ]; then
  echo "$kind_containers" | xargs -r docker rm -f
fi

# kn-quickstart's local registry container is not labeled as part of the
# kind cluster, so it survives the removal above unless handled separately.
if docker ps -a --format '{{.Names}}' | grep -qx "kind-registry"; then
  docker rm -f kind-registry
fi

if docker network inspect kind >/dev/null 2>&1; then
  docker network rm kind
fi

echo "Teardown complete."
