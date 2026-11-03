#!/bin/bash

set -Eeuo pipefail

echo "127.0.0.1 deployer.florca.localhost engine.florca.localhost" >> /etc/hosts

mkdir -p /var/log/florca

# Fails loudly (dumps the relevant log to stderr) instead of silently: this
# is exactly the failure mode hit when this container's required ports
# were already bound on the host under --network host - the container
# exited immediately with an empty `docker logs`, since the failing
# command's own output only ever went to a log file inside the container.
die_with_log() {
  echo "$1" >&2
  echo "--- $2 ---" >&2
  cat "$2" >&2 2>/dev/null || echo "(log file not found)" >&2
  exit 1
}

caddy run --config Caddyfile > /var/log/florca/caddy.log 2>&1 &
for _ in $(seq 1 15); do
  nc -z localhost 8080 && break
  sleep 1
done
nc -z localhost 8080 || die_with_log "Caddy failed to start (port 8080 not listening)." /var/log/florca/caddy.log

# shellcheck disable=SC2024
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/data start > /var/log/florca/postgres.log 2>&1 \
  || die_with_log "Postgres failed to start." /var/log/florca/postgres.log

if ! docker version >/dev/null 2>&1; then
  echo "Cannot reach the Docker daemon from inside this container." >&2
  echo "Re-run with: -v /var/run/docker.sock:/var/run/docker.sock" >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -q .; then
  existing_cluster="$(kind get clusters | head -1)"
  echo "Reusing existing kind cluster: $existing_cluster"
  # The cluster (a sibling container on the host daemon) outlives this
  # wrapper container, but ~/.kube/config does not: it's local to this
  # container's filesystem and this is a fresh one. Without re-exporting
  # it, kubectl/kn/florca-deployer would all fail with "no configuration
  # has been provided" despite the cluster being perfectly healthy.
  kind export kubeconfig --name "$existing_cluster"
else
  echo "Creating a Knative-enabled kind cluster (this can take a very long time)"
  kn quickstart kind --registry --kubernetes-version 1.32.8
fi

# This container runs with --network host (see ../run.sh for why: kind's
# kubeconfig assumes 127.0.0.1 is the host's, which is only true under
# host networking). That means it has no container IP of its own on the
# "kind" Docker network to hand to Knative pods - instead, give them the
# host's own IP on that network (its gateway from the node container's
# point of view), which host networking makes directly reachable.
# The "kind" network is dual-stack (IPv4 + IPv6); IPAM.Config's order is
# not guaranteed to put IPv4 first, and sslip.io's dashed-IP hostname
# scheme only works for IPv4, so pick the IPv4 gateway explicitly.
GATEWAYS="$(docker network inspect kind --format '{{range .IPAM.Config}}{{.Gateway}} {{end}}' 2>/dev/null || true)"
GATEWAY_IP="$(echo "$GATEWAYS" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)"
if [ -z "$GATEWAY_IP" ]; then
  echo "Could not determine the 'kind' Docker network's IPv4 gateway." >&2
  exit 1
fi
GATEWAY_IP_DASHES="${GATEWAY_IP//./-}"
export ENGINE_URL_FOR_ACCESS_FROM_KN="http://engine.${GATEWAY_IP_DASHES}.sslip.io:8080"
echo "Knative functions will reach the engine via ${ENGINE_URL_FOR_ACCESS_FROM_KN}"

florca-deployer > /var/log/florca/deployer.log 2>&1 &
florca-engine > /var/log/florca/engine.log 2>&1 &

for _ in $(seq 1 30); do
  nc -z localhost 8000 && break
  sleep 1
done
nc -z localhost 8000 || die_with_log "florca-deployer failed to start (port 8000 not listening)." /var/log/florca/deployer.log

for _ in $(seq 1 30); do
  nc -z localhost 8001 && break
  sleep 1
done
nc -z localhost 8001 || die_with_log "florca-engine failed to start (port 8001 not listening)." /var/log/florca/engine.log

echo "Deploying examples/flexi-consensus-kn (builds and pushes a container image via func/kn)"
florca deploy --workflow-directory examples/flexi-consensus-kn flexi-consensus-kn

echo "Running the flexi-consensus-kn workflow (5 simulated nodes, default target/slot/epochs)"
output="$(florca run --deployment-name flexi-consensus-kn --wait)" || true
echo "$output"

# Compact result record, copied to the host by ../run.sh (results/).
RESULT_DIR=/var/log/florca/result
mkdir -p "$RESULT_DIR"
echo "$output" > "$RESULT_DIR/run-output.txt"
# Every function invocation of the run (the coordinator and the 5 participants), with inputs and outputs.
florca inspect --latest --show-inputs --show-outputs > "$RESULT_DIR/inspect.txt" 2>&1 || true
# The coordinator's negotiation log (epochs, ACKs/NACKs, consensus outcome).
# Cleaned up: color codes, timestamp and run-id prefix removed; identical consecutive
# lines (one per participant) are collapsed into a "(xN)" count.
grep -F '[START]' /var/log/florca/engine.log \
  | sed -E 's/\x1b\[[0-9;]*m//g; s/^.*(\[START\].*) run="[0-9]+"$/\1/' \
  | uniq -c \
  | awk '{n=$1; $1=""; sub(/^ /,""); print (n>1 ? $0 " (x" n ")" : $0)}' \
  > "$RESULT_DIR/coordination.log" || true

echo
echo "==> Result record (full files in $RESULT_DIR, copied to results/ on the host)"
echo "--- Final result (Output line of the run) ---"
grep -E '^Output:' "$RESULT_DIR/run-output.txt" || echo "(no Output line)"
echo "--- Coordination log (coordinator, [START] lines) ---"
cat "$RESULT_DIR/coordination.log"
echo "--- Participant invocations ---"
grep -E 'participant' "$RESULT_DIR/inspect.txt" || echo "(none found)"
echo

if echo "$output" | grep -q "Success: true"; then
  echo "==> Functional check PASSED (Knative/kind path)"
else
  echo "Functional check FAILED: expected \"Success: true\" in the output above." >&2
  exit 1
fi
