#!/usr/bin/env bash

set -euo pipefail

TAG_BASE="zimagedk/ihccaptain"

VERSION="${1:-}"
BUILD="${2:-}"
shift 2
ARCHIVES=("$@")

BUILD_IMG="${BUILD}/image"
BUILDER=""

BINARY_64="${BUILD_IMG}/goihcapp.amd64"
BINARY_ARM="${BUILD_IMG}/goihcapp.arm"

TEMP_DIR="$(mktemp -d)"

usage() {
    echo """
  Usage:
  - ${0} <version> <work folder> <amd64 archive> <arm64 archive>
  - ${0} <version> --push
  - ${0} <version> --get-tag

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
    local arch="${1}"
    local binary="${2}"
    "${BUILDER}" build \
        --file Containerfile \
        --platform "linux/${arch}" \
        --build-arg "TARGETARCH=${arch}" \
        --build-arg "BINARY=$(basename "${binary}")" \
        --tag "ihccaptain:${arch}" \
        "${BUILD_IMG}"
}

remove_tags() {
    heading "Image cleanup"
    for tag in "$@"; do
        if "${BUILDER}" manifest exists "${tag}"; then
            "${BUILDER}" manifest rm "${tag}"
        fi
    done

    for tag in "localhost/ihccaptain:amd64" "localhost/ihccaptain:arm64"; do
        if podman images | grep -q "${tag}"; then
            podman rmi "${tag}"
        fi
    done
}

push_image() {

    heading "Pushing to remote registry"

    for tag in "${FULL_TAGS[@]}"; do
        green "Pushing to remote registry: ${tag}"
        "${BUILDER}" manifest push --all "${tag}"
    done

}

create_tag() {
    echo "${TAG_BASE}:${VERSION}"
}

if which podman >/dev/null; then
    BUILDER=podman
elif which docker >/dev/null; then
    BUILDER=docker
else
    echo "No means of building the image found, please install buildah, podman or docker"
    exit 1
fi

if [[ "${VERSION}" =~ ^(([0-9]+)\.[0-9]+)\.[0-9]+ ]] ; then
    MINOR="${BASH_REMATCH[1]}"
    MAJOR="${BASH_REMATCH[2]}"
else
    error "No or wrong formatted version specified: '${VERSION}'"
    exit 2
fi

TAGS=(latest "${MAJOR}" "${MINOR}" "${VERSION}")

FULL_TAGS=()

for tag in "${TAGS[@]}"; do
    FULL_TAGS+=("${TAG_BASE}:${tag}")
done

if [ "${BUILD}" = "--get-tag" ]; then
    create_tag
    exit 0
elif [ "${BUILD}" = "--push" ]; then
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

green """
##################################
 Building using ${BUILDER}
 Version tags: ${TAGS[*]}
##################################"""

heading "Building for AMD64"

build_image amd64 "${BINARY_64}"

heading "Building for AMD64"

build_image arm64 "${BINARY_ARM}"

heading "Creating image manifest"

VERSION_TAG="${TAG_BASE}:${VERSION}"

id="$("${BUILDER}" manifest create "${VERSION_TAG}")"
"${BUILDER}" manifest add --all "${VERSION_TAG}" "containers-storage:localhost/ihccaptain:amd64" >/dev/null
"${BUILDER}" manifest add --all "${VERSION_TAG}" "containers-storage:localhost/ihccaptain:arm64" >/dev/null

"${BUILDER}" tag "${VERSION_TAG}" "${FULL_TAGS[@]}"

green "Image id:  ${id}"
for tag in "${FULL_TAGS[@]}"; do
    green "Image tag: ${tag}"
done

echo ""
