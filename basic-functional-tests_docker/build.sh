#!/bin/bash

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
cd "$DIR"
# shellcheck disable=SC1091
source ../versions.sh

if ! docker build \
	--build-arg CARGO_PROFILE="${CARGO_PROFILE:-release}" \
	--build-arg FLORCA_TARBALL_URL="${FLORCA_TARBALL_URL}" \
	--build-arg FLORCA_TARBALL_SHA256="${FLORCA_TARBALL_SHA256}" \
	-f ./Dockerfile . -t florca-ae; then
	cat >&2 <<'MSG'

Build failed. The Dockerfile pins its base images by digest (@sha256:...).
If the error above says that an image or digest could not be pulled or
found, the pinned digest may no longer be available from its registry.
In that case, run ../unpin-images.sh to switch to the plain image tags
(it prints a warning and asks for confirmation), then re-run this script.
MSG
	exit 1
fi
