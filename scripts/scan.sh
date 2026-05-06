#!/usr/bin/env bash

# This script performs a vulnerability scan of the specified image

set -uo pipefail

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
BUILD_FOLDER="${WORKSPACE}/build"
CACHE_FOLDER="${BUILD_FOLDER}/.cache"

TRIVY_IMAGE="docker.io/aquasec/trivy:canary"

OUTPUT_FOLDER="${1:-}"
IMAGE="${2:-}"

if [ -z "${IMAGE}" ]; then
    echo "No image specified"
    exit 1
fi

if [ -z "${OUTPUT_FOLDER}" ]; then
    echo "No output folder specified"
    exit 1
fi

log() {
    echo "$(date --iso-8601=seconds) $*"
}

podman pull "${TRIVY_IMAGE}"

mkdir -p "${CACHE_FOLDER}"

scan_arch() {
    local arch="${1}"
    local platform="linux/${arch}"
    local run_args=(--rm)
    local runner=podman
    if [ -z "${XDG_SESSION_ID:-}" ]; then
        runner=docker
    else
        run_args+=(-ti)
    fi
    log "Running: ${runner} run ${run_args[*]}" \

    "${runner}" run "${run_args[@]}" \
        -v "${CACHE_FOLDER}:/root/.cache/" \
        -v "${OUTPUT_FOLDER}:/root/report" \
        "${TRIVY_IMAGE}" image \
        --platform "${platform}" \
        --skip-version-check \
        --scanners vuln \
        --exit-code 67 \
        --format template \
        --template "@contrib/html.tpl" \
        --output "/root/report/vulnerabilities-${arch}.html" \
        "${IMAGE}"
}

ok=true

scan_arch "amd64" || ok=false
scan_arch "arm64" || ok=false

$ok
