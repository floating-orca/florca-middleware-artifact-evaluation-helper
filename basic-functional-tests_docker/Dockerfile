# syntax=docker/dockerfile:1
##
## Headless, self-contained build of floating-orca/florca v0.8.1
## (DOI 10.5281/zenodo.19712026) for Middleware 2026 artifact evaluation.
##
## This repository does not carry a copy of florca's source: this stage
## fetches and checksum-verifies the exact archived v0.8.1 tarball from
## Zenodo at build time. See ../versions.sh for the pinned URL/checksum.

FROM docker.io/library/rust:1.94-trixie AS fetch

ARG FLORCA_TARBALL_URL
ARG FLORCA_TARBALL_SHA256

WORKDIR /usr/src
RUN test -n "${FLORCA_TARBALL_URL}" && test -n "${FLORCA_TARBALL_SHA256}"
RUN apt-get update && apt-get install -y --no-install-recommends unzip ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -fL "${FLORCA_TARBALL_URL}" -o florca-src.zip \
  && echo "${FLORCA_TARBALL_SHA256}  florca-src.zip" | sha256sum -c - \
  && unzip -q florca-src.zip \
  && rm florca-src.zip \
  && mv "$(find . -mindepth 1 -maxdepth 1 -type d)" florca

FROM fetch AS build

WORKDIR /usr/src/florca

ARG CARGO_PROFILE=release

RUN --mount=type=cache,target=/usr/src/florca/target/ \
  --mount=type=cache,target=/usr/local/cargo/registry/ \
  <<EOF
set -e
case "${CARGO_PROFILE}" in
  dev)
    TARGET_DIR_NAME=debug
    CARGO_BUILD_ARGS=""
    ;;
  release)
    TARGET_DIR_NAME=release
    CARGO_BUILD_ARGS="--release"
    ;;
  *)
    echo "Invalid CARGO_PROFILE: ${CARGO_PROFILE}. Expected 'dev' or 'release'." >&2
    exit 1
    ;;
esac
cargo build ${CARGO_BUILD_ARGS}
cp target/${TARGET_DIR_NAME}/florca-deployer /usr/local/bin/florca-deployer
cp target/${TARGET_DIR_NAME}/florca-engine /usr/local/bin/florca-engine
cp target/${TARGET_DIR_NAME}/florca /usr/local/bin/florca
EOF

# Build the user/developer guide (book/) the same way scripts/release.sh
# does for real releases, so the AE check also confirms the shipped
# documentation builds cleanly from the archived source - not just the
# binaries. book/src/*.md pulls in files from ../../examples via mdBook
# {{#include}} directives, so this needs the full fetched source tree,
# not just book/ in isolation.
FROM fetch AS book

WORKDIR /usr/src/florca
ARG MDBOOK_VERSION=0.5.4

RUN curl -fL "https://github.com/rust-lang/mdBook/releases/download/v${MDBOOK_VERSION}/mdbook-v${MDBOOK_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o mdbook.tar.gz \
  && tar -xzf mdbook.tar.gz \
  && ./mdbook build book \
  && rm mdbook mdbook.tar.gz

# ---

FROM docker.io/library/debian:trixie-slim

RUN apt-get update && apt-get install -y \
  ca-certificates \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  curl \
  && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
  && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
RUN apt-get update && apt-get install -y \
  bats \
  bats-support \
  bats-assert \
  caddy \
  jq \
  netcat-traditional \
  postgresql \
  postgresql-client \
  sudo \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/florca

COPY container-scripts e2e/container-scripts
RUN e2e/container-scripts/initdb.sh

COPY --from=docker.io/denoland/deno:bin-2.7.9 /deno /usr/local/bin/deno
COPY --from=build /usr/src/florca/deno.json /usr/src/florca/deno.lock ./
COPY --from=build /usr/src/florca/packages packages
RUN deno install --entrypoint packages/driver/main.ts

COPY --from=build /usr/local/bin/florca-deployer /usr/local/bin/florca-deployer
COPY --from=build /usr/local/bin/florca-engine /usr/local/bin/florca-engine
COPY --from=build /usr/local/bin/florca /usr/local/bin/florca

COPY --from=build /usr/src/florca/dist/src/.env .env
COPY --from=build /usr/src/florca/dist/src/Caddyfile Caddyfile

# Bundled so `run-functional-check.sh full` is self-contained (no volume
# mount / separate fetch needed to exercise the example workflow suite).
COPY --from=build /usr/src/florca/examples examples

# The rendered user/developer guide, extractable via extract-docs.sh.
COPY --from=book /usr/src/florca/book/book book-docs

ENTRYPOINT ["e2e/container-scripts/entrypoint.sh"]
