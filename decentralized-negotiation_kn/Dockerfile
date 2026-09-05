# syntax=docker/dockerfile:1
##
## Self-contained Knative/remote-function check for floating-orca/florca
## v0.8.1 (DOI 10.5281/zenodo.19712026), Middleware 2026 artifact
## evaluation.
##
## Pins exact versions of kind/kubectl/kn/kn-quickstart/func at build time
## (rather than a host script fetching "whatever's current"), and runs
## with the host's Docker socket mounted so `kind` creates its cluster as
## sibling containers on the host daemon - the standard way to run kind
## from inside a container (not nested Docker-in-Docker).
##
## Caddy, Postgres, the deployer, and the engine all run inside this same
## container (as in ../docker/), so the only thing reaching outside of it
## is `kind`/Knative's own use of the Docker socket.

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
cargo build --release
cp target/release/florca-deployer /usr/local/bin/florca-deployer
cp target/release/florca-engine /usr/local/bin/florca-engine
cp target/release/florca /usr/local/bin/florca
EOF

# ---

FROM docker.io/library/debian:trixie-slim

RUN apt-get update && apt-get install -y \
  ca-certificates \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  curl \
  gnupg \
  iproute2 \
  && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
  && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
RUN apt-get update && apt-get install -y \
  caddy \
  netcat-traditional \
  postgresql \
  postgresql-client \
  sudo \
  && rm -rf /var/lib/apt/lists/*

# Pinned Kubernetes/Knative tooling (same versions as documented in the
# florca user guide's "Knative on a self-hosted server" chapter).
RUN curl -fLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64" \
  && curl -fLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.32.8/bin/linux/amd64/kubectl" \
  && curl -fLo /usr/local/bin/kn "https://github.com/knative/client/releases/download/knative-v1.18.0/kn-linux-amd64" \
  && curl -fLo /usr/local/bin/kn-quickstart "https://github.com/knative-extensions/kn-plugin-quickstart/releases/download/knative-v1.18.0/kn-quickstart-linux-amd64" \
  && curl -fLo /usr/local/bin/func "https://github.com/knative/func/releases/download/knative-v1.18.1/func_linux_amd64" \
  && chmod +x /usr/local/bin/kind /usr/local/bin/kubectl /usr/local/bin/kn /usr/local/bin/kn-quickstart /usr/local/bin/func
# kn discovers plugins named kn-* on $PATH, so no extra registration step
# is needed for `kn quickstart` to find kn-quickstart above.

# Docker CLI only (talks to the host daemon via the mounted socket; no
# dockerd/dind here).
COPY --from=docker.io/library/docker:28-cli /usr/local/bin/docker /usr/local/bin/docker

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
COPY --from=build /usr/src/florca/examples/flexi-consensus-kn examples/flexi-consensus-kn

ENTRYPOINT ["e2e/container-scripts/entrypoint.sh"]
