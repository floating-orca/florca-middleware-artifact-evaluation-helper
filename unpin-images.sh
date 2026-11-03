#!/bin/bash
#
# Removes the "@sha256:..." digest pins from the base images in both
# Dockerfiles, so that the plain tags (e.g. rust:1.94-trixie) are used.
#
# Use this only if a pinned digest can no longer be pulled from its
# registry (the build then fails at the corresponding FROM / COPY --from
# line). The digests exist so that every evaluator builds on the exact
# same base images; without them the tags may resolve to newer, untested
# image contents.

set -Eeuo pipefail

DIR="$(dirname "$(realpath "$0")")"
FILES=("$DIR/basic-functional-tests_docker/Dockerfile" "$DIR/decentralized-negotiation_kn/Dockerfile")

echo "WARNING: this removes the image digest pins from:" >&2
printf '  %s\n' "${FILES[@]}" >&2
echo "The base images will then follow their tags and may differ from the" >&2
echo "ones the artifact was tested with. Results may deviate." >&2
if [ "${1:-}" != "--yes" ]; then
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

sed -i -E 's/@sha256:[0-9a-f]{64}//g' "${FILES[@]}"
echo "Digest pins removed. Re-run the build.sh scripts."
