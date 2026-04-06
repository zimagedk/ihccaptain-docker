#!/usr/bin/env bash

# This script performs a vulnerability scan of the specified image

set -uo pipefail

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"

TRIVY_IMAGE="docker.io/aquasec/trivy:canary"

IMAGE="${1:-}"

if [ -z "${IMAGE}" ]; then
    echo "No image specified"
    exit 1
fi

podman pull "${TRIVY_IMAGE}"

mkdir -p "${WORKSPACE}/build/.cache"

scan_arch() {
    local arch="${1}"
    podman run -ti --rm \
        -v "${WORKSPACE}/build/.cache:/root/.cache/" \
        "${TRIVY_IMAGE}" image \
        "--platform=${arch}" \
        --skip-version-check \
        --scanners vuln \
        --exit-code 67 \
        "${IMAGE}"
}

scan_arch "linux/amd64" && \
scan_arch "linux/arm64"
