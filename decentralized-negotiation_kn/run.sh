#!/bin/bash
#
# Runs the Knative/remote-function functional check: creates a local
# Knative-enabled kind cluster (as sibling containers on your host Docker
# daemon, via the mounted socket - not nested Docker-in-Docker), deploys
# examples/flexi-consensus-kn (the paper's Knative experiment: 5 simulated
# nodes negotiating via a Knative "participant" function), and checks for
# a successful run.
#
# Usage:
#   ./build.sh
#   ./run.sh
#   ./teardown.sh   # when done - deletes the kind cluster and this container
#
# Expect a few GB of free disk space.
#
# Runs with --network host: kind's generated kubeconfig points at
# 127.0.0.1:<port> on the assumption that the caller shares the host's
# network namespace (true when run on the host directly; not true for a
# container that only has the Docker socket mounted). Without this, kind
# itself comes up fine but every kubectl call - including kn-quickstart's
# own local-registry setup - fails with "connection refused". Host
# networking means this container's ports (8000/8001/8080/443/5432)
# really are the host's ports: don't run this alongside anything else
# using them (e.g. ../basic-functional-tests_docker/'s compose stack, which is otherwise
# unaffected since it does not use host networking itself).

set -Eeuo pipefail

CONTAINER_NAME="florca-ae-kind-run"
REQUIRED_PORTS=(5432 8000 8001 8080 443)

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "Container $CONTAINER_NAME already exists. Run ./teardown.sh first to start fresh." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Cannot reach the Docker daemon. Is Docker running, and do you have permission to use it?" >&2
  exit 1
fi

# Checked up front instead of letting Postgres/Caddy fail to bind
# silently inside the container - that failure mode produces an
# immediately-exited container with an empty `docker logs`, since the
# failing command's own output goes to an in-container log file, not
# the container's stdout.
busy_ports=()
for port in "${REQUIRED_PORTS[@]}"; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    exec 3>&- 3<&-
    busy_ports+=("$port")
  fi
done

if [ "${#busy_ports[@]}" -gt 0 ]; then
  echo "Port(s) ${busy_ports[*]} are already in use on this host." >&2
  echo "This container runs with --network host, so it needs all of: ${REQUIRED_PORTS[*]}." >&2
  echo "Whatever is listening on those ports:" >&2
  docker ps --format '  {{.Names}}: {{.Ports}}' 2>/dev/null >&2
  echo "Stop the conflicting service(s) (e.g. 'docker compose down' for another florca stack, including ../basic-functional-tests_docker/'s) and try again." >&2
  exit 1
fi

docker run \
  --name "$CONTAINER_NAME" \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  florca-ae-kind
