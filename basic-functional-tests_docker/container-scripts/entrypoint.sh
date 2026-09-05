#!/bin/bash

set -Eeuo pipefail

echo "127.0.0.1 deployer.florca.localhost engine.florca.localhost" >> /etc/hosts

mkdir -p /var/log/florca

caddy run --config Caddyfile > /var/log/florca/caddy.log 2>&1 &

# shellcheck disable=SC2024
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/data \
  -o "-c fsync=off -c synchronous_commit=off -c full_page_writes=off" \
  start > /var/log/florca/postgres.log 2>&1

florca-deployer > /var/log/florca/deployer.log 2>&1 &
florca-engine > /var/log/florca/engine.log 2>&1 &

while ! nc -z localhost 8000; do
    sleep 1
done
while ! nc -z localhost 8001; do
    sleep 1
done

if [ "$#" -gt 0 ]; then
  exec "$@"
else
  # otherwise, keep the container running
  tail -f /dev/null
fi
