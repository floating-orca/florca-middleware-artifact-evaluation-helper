#!/bin/bash

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
cd "$DIR"
# shellcheck disable=SC1091
source ../versions.sh

docker build \
	--build-arg CARGO_PROFILE="${CARGO_PROFILE:-release}" \
	--build-arg FLORCA_TARBALL_URL="${FLORCA_TARBALL_URL}" \
	--build-arg FLORCA_TARBALL_SHA256="${FLORCA_TARBALL_SHA256}" \
	-f ./Dockerfile . -t florca-ae-kind
