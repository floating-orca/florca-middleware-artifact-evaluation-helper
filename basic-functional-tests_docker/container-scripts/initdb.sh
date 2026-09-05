#!/bin/bash

set -Eeuo pipefail

sudo -u postgres /usr/lib/postgresql/17/bin/initdb -D /var/lib/postgresql/data
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/data start
sudo -u postgres createdb -O postgres deployer
sudo -u postgres createdb -O postgres engine
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'mysecretpassword';"
sudo -u postgres /usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/data stop
