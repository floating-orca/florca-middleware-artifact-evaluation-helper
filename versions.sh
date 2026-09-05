#!/bin/bash
# Single source of truth for exactly which florca source this helper fetches
# and exercises. Sourced by basic-functional-tests_docker/build.sh and
# decentralized-negotiation_kn/build.sh.
#
# The tarball is fetched from the permanent Zenodo archive (the record
# backing the Artifacts Available badge), not from GitHub, so this keeps
# working even if the floating-orca/florca repository or the v0.8.1 tag
# were ever to disappear. The checksum pins the fetch to the exact archived
# content. The GitHub tag is provided as a documented fallback below.

FLORCA_TAG="v0.8.1"
FLORCA_REPO="floating-orca/florca"
FLORCA_ZENODO_DOI="10.5281/zenodo.19712026"
FLORCA_TARBALL_URL="https://zenodo.org/records/19712026/files/floating-orca/florca-v0.8.1.zip?download=1"
FLORCA_TARBALL_SHA256="7bd90741a27f76fd6f041f0858c8ef124ffcd7bc70389f6b7f06bc6d4942554b"
FLORCA_TARBALL_FORMAT="zip"

# Fallback, only if the Zenodo record above is ever unreachable:
FLORCA_GITHUB_FALLBACK_URL="https://github.com/${FLORCA_REPO}/archive/refs/tags/${FLORCA_TAG}.tar.gz"
FLORCA_GITHUB_FALLBACK_SHA256="7e2436d891cd258f5153d21135e9de0c662f54fae5a213ee295583d9ec3d2433"
