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

podman pull "${TRIVY_IMAGE}"

mkdir -p "${CACHE_FOLDER}"

scan_arch() {
    local arch="${1}"
    local platform="linux/${arch}"
    local podman_args=(--rm)
    if tty -s; then
        podman_args+=(-ti)
    fi
    podman run "${podman_args[@]}" \
        -v "${CACHE_FOLDER}:/root/.cache/" \
        -v "${OUTPUT_FOLDER}:/root/report" \
        "${TRIVY_IMAGE}" image \
        "--platform=${platform}" \
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
