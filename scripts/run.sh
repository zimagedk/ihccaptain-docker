#!/usr/bin/env bash

# Script for local testing

set -euo pipefail

TAG_BASE="zimagedk/ihccaptain"
VERSION=latest
PORT=9000

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
DATA_FOLDER="${WORKSPACE}/run/podman"

mkdir -p "${DATA_FOLDER}"

podman run --rm -ti \
    -p "${PORT}:80" \
    -v "${DATA_FOLDER}:/app/data" \
    "${TAG_BASE}:${VERSION}"
