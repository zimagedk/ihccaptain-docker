#!/usr/bin/env bash

# This script builds the images

set -euo pipefail

ALPINE_MAJOR="3"
ALPINE_BASE="docker.io/library/alpine"
TAG_BASE="zimagedk/ihccaptain"

LOCAL_AMD64_TAG="localhost/ihccaptain:amd64"
LOCAL_ARM64_TAG="localhost/ihccaptain:arm64"

KNOWN_VERSION=""

if [ -z "${WORKSPACE:-}" ]; then
    WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
fi

VERSION_FILE="${WORKSPACE}/.alpine_version"
TEMP_DIR="$(mktemp -d)"

if [ -r "${VERSION_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${VERSION_FILE}"
fi

usage() {
    echo """
  Usage:
  - ${0} <version> <work folder> <amd64 archive> <arm64 archive>
  - ${0} <version> --push

  Builds a multi-architecture OCI image for IHC Captain
  The order of the archives may be swapped
    """
}

red() {
    echo -e "\e[0;31m$*\e[0m"
}

green() {
    echo -e "\e[0;32m$*\e[0m"
}

heading() {
    echo -e "\n\e[0;32m### $* ###\e[0m\n"
}

error() {
    red "$*" 1>&2
}

leaving() {
    rm -rf "${TEMP_DIR}"
}

trap leaving EXIT

unpack_file() {
    local archive="${1:-}"
    local binary
    if [ -z "${archive}" ] || [ ! -r "${archive}" ]; then
        echo "Release file not found: '${archive}'"
        exit 1
    fi

    if [[ "${archive}" != *"${VERSION}"*  ]]; then
        error "Release file name must contain the version: ${VERSION}"
        exit 2
    fi

    rm -rf "${TEMP_DIR:?}/"*
    unzip -nq -d "${TEMP_DIR}" "${archive}"

    readarray -t content < <(ls -1 "${TEMP_DIR}")

    if [ "${#content[@]}" -ne 1 ]; then
        echo "Archives should contain exactly one file, but found: ${content[*]}"
        exit 1
    fi

    binary="${TEMP_DIR}/${content[0]}"

    if file "${binary}" | grep -q "executable.*x86-64"; then
        mv "${binary}" "${BINARY_64}"
        chmod +x "${BINARY_64}"
    elif file "${binary}" | grep -q "executable.*aarch64"; then
        mv "${binary}" "${BINARY_ARM}"
        chmod +x "${BINARY_ARM}"
    else
        echo "Unpacked file $(basename "${binary}") must be an amd- or arm-64bit executable"
        exit 1
    fi
}

build_image() {
    local from_image="${1}"
    local arch="${2}"
    local binary="${3}"
    buildah build \
        --file Containerfile \
        --platform "linux/${arch}" \
        --build-arg "FROM_IMAGE=${from_image}" \
        --build-arg "TARGETARCH=${arch}" \
        --build-arg "BINARY=$(basename "${binary}")" \
        --tag "ihccaptain:${arch}" \
        "${BUILD_IMG}"
}

remove_tags() {
    heading "Image cleanup"
    for tag in "$@"; do
        buildah manifest rm "${tag}" >/dev/null 2>&1 || true
    done

    for tag in "${LOCAL_AMD64_TAG}" "${LOCAL_ARM64_TAG}"; do
        if podman images | grep -q "${tag}"; then
            podman rmi "${tag}"
        fi
    done
}

push_image() {

    heading "Pushing to remote registry"

    for tag in "${FULL_TAGS[@]}"; do
        green "Pushing to remote registry: ${tag}"
        buildah manifest push --all "${tag}"
    done
}

determine_alpine_version() {
    podman search --list-tags --limit 10000 --format "{{.Tag}}" "${ALPINE_BASE}" | grep -E "^${ALPINE_MAJOR}" | sort -V | tail -n1
}

save_alpine_version() {
    echo "KNOWN_VERSION=${1}" > "${VERSION_FILE}"
}

if [ -z "${1:-}" ]; then
    red "No arguments provided"
    usage
    exit 1
fi

if [ "${1}" == "latest-tag" ]; then
    echo "${TAG_BASE}:latest"
    exit
elif [ "${1}" == "alpine-version-remote" ]; then
    determine_alpine_version
    exit
elif [ "${1}" == "alpine-version-local" ]; then
    echo "${KNOWN_VERSION}"
    exit
fi

VERSION="${1:-}"
BUILD="${2:-}"
shift 2
ARCHIVES=("$@")

BUILD_IMG="${BUILD}/image"

BINARY_64="${BUILD_IMG}/goihcapp.amd64"
BINARY_ARM="${BUILD_IMG}/goihcapp.arm"

if [[ "${VERSION}" =~ ^(([0-9]+)\.[0-9]+)\.[0-9]+ ]] ; then
    MINOR="${BASH_REMATCH[1]}"
    MAJOR="${BASH_REMATCH[2]}"
else
    error "No or wrong formatted version specified: '${VERSION}'"
    exit 2
fi

ALPINE_VERSION="$(determine_alpine_version)"

TAGS=(latest \
    "${MAJOR}" \
    "${MINOR}" \
    "${VERSION}" \
    "${MAJOR}-alpine-${ALPINE_VERSION}" \
    "${MINOR}-alpine-${ALPINE_VERSION}" \
    "${VERSION}-alpine-${ALPINE_VERSION}")

FULL_TAGS=()

for tag in "${TAGS[@]}"; do
    FULL_TAGS+=("${TAG_BASE}:${tag}")
done

if [ "${BUILD}" = "--push" ]; then
    push_image
    exit $?
elif [ -z "${1:-}" ]; then
    usage
    exit 0
elif [ ! -d "${BUILD}" ]; then
    error "work folder must be folder"
    exit 1
fi

if [ "${#ARCHIVES[@]}" -ne 2 ]; then
    echo "Two binary archives must be specified, was: '${ARCHIVES[*]}'"
    exit 1
fi

rm -rf "${BUILD_IMG}"
mkdir -p "${BUILD_IMG}"

for file in "${ARCHIVES[@]}"; do
    unpack_file "${file}"
done

if [ ! -r "${BINARY_64}" ]; then
    error "x86-64 binary not unpacked: ${BINARY_64}"
    exit 1
fi

if [ ! -r "${BINARY_ARM}" ]; then
    error "ARM-64 binary not unpacked: ${BINARY_ARM}"
    exit 1
fi

remove_tags "${FULL_TAGS[@]}"

cp "${WORKSPACE}/Containerfile" "${BUILD_IMG}"

green "#########################"
green " App:    ${VERSION}"
green " Alpine: ${ALPINE_VERSION}"
green " Tags:"
for tag in "${TAGS[@]}"; do
    green "   ${tag}"
done

green "#########################"

FROM_IMAGE="${ALPINE_BASE}:${ALPINE_VERSION}"

heading "Building for AMD64"

build_image "${FROM_IMAGE}" amd64 "${BINARY_64}"

heading "Building for ARM64"

build_image "${FROM_IMAGE}" arm64 "${BINARY_ARM}"

heading "Creating image manifest"

VERSION_TAG="${TAG_BASE}:${VERSION}"

id="$(buildah manifest create "${VERSION_TAG}")"
buildah manifest add --all "${VERSION_TAG}" "containers-storage:${LOCAL_AMD64_TAG}" >/dev/null
buildah manifest add --all "${VERSION_TAG}" "containers-storage:${LOCAL_ARM64_TAG}" >/dev/null

buildah tag "${VERSION_TAG}" "${FULL_TAGS[@]}"

green "Image id:  ${id}"
for tag in "${FULL_TAGS[@]}"; do
    green "Image tag: ${tag}"
done

save_alpine_version "${ALPINE_VERSION}"

echo ""
