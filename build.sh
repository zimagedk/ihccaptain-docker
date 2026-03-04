#!/usr/bin/env bash

TAG_BASE="zimagedk/ihccaptain"

# Change to none-beta when released
DOWNLOAD_URL_BASE="https://jemi.dk/ihc/beta/download.php?file="
UPDATE_CHECK_URL="https://jemi.dk/ihc/beta/update.php"
SUPPLIED_FILE=""

HERE="$(dirname "$(realpath $0)")"
BUILD="${HERE}/build"
VERSION_FILE="${BUILD}/latest_version"
KNOWN_VERSION=""
VERSION=""

BUILDER=""
BUILD_CMD="build"

BINARY="${BUILD}/goihccap"

TEMP_DIR="$(mktemp -d)"

PUSH=false
FORCE=false

mkdir -p "${BUILD}"

error() {
    echo "$*" 1>&2
}

leaving() {
    rm -rf "${TEMP_DIR}"
}

trap leaving EXIT

while [ -n "${1:-}" ]; do
    if [ "${1}" = "--push" ]; then
        PUSH=true
        shift
    elif [ "${1}" = "--force" ]; then
        FORCE=true
        shift
    elif [ -r "${1}" ]; then
        SUPPLIED_FILE="${1}"
        shift
    fi
done

get_release_file() {

    VERSION="$(curl --get --fail --no-progress-meter "${UPDATE_CHECK_URL}" | jq -r '.latest_version')"

    if ! $FORCE && [ -z "${VERSION}" ]; then
        error "Unable to get latest available version"
        exit 1
    fi

    # Check om fil findes, ellers hent

    if ! $FORCE && [ "${KNOWN_VERSION}" = "${VERSION}" ]; then
        echo "Already on latest version"
        exit 0
    fi

    # TODO map til filnavn
    find "${BUILD}" -maxdepth 1 -name "*.zip" -exec rm -f {} \;
}

if [ -r "${VERSION_FILE}" ]; then
    . "${VERSION_FILE}"
fi

if [ -z "${SUPPLIED_FILE}" ]; then
    RELEASE_FILE="$(get_release_file)"
else
    RELEASE_FILE="${SUPPLIED_FILE}"
    VERSION="${KNOWN_VERSION}"
fi

if [ -z "${RELEASE_FILE}" ] || [ ! -r "${RELEASE_FILE}" ]; then
    echo "Release file not found: '${RELEASE_FILE}'"
    exit 1
fi

if [[ "${RELEASE_FILE}" != *"${VERSION}"*  ]]; then
    error "Release file name must contain the version: ${VERSION}"
    exit 2
fi

unzip -nq -d "${TEMP_DIR}" "${RELEASE_FILE}"

readarray -t APPS_UNPACKED < <(ls -1 "${TEMP_DIR}")

if [ "${#APPS_UNPACKED[@]}" -ne 1 ]; then
    echo "Archive should contain exactly one file, but found: ${APPS_UNPACKED[*]}"
    exit 1
fi

APP_UNPACKED="${TEMP_DIR}/${APPS_UNPACKED[0]}"

if ! file "${APP_UNPACKED}" | grep -q "executable.*x86-64"; then
    echo "Unpacked file $(basename "${APP_UNPACKED}") is not a 64-bit executable"
    exit 1
fi

MAJOR="$(echo "${VERSION}" | grep -oE "^[0-9]+")"
MINOR="$(echo "${VERSION}" | grep -oE "^[0-9]+\.[0-9]+")"
LABEL="$(echo "${RELEASE_FILE}" | grep -oE "[0-9]+-[0-9]+")"

# if which buildah >/dev/null; then
#     BUILDER=buildah
if which podman >/dev/null; then
    BUILDER=podman
elif which docker >/dev/null; then
    BUILDER=docker
else
    echo "No means of building the image found, please install buildah, podman or docker"
    exit 1
fi

TAGS=(latest "${MAJOR}" "${MINOR}" "${VERSION}")
if [ -n "${LABEL}" ]; then
    TAGS+=("${VERSION}-$LABEL")
fi

echo ""
echo "############################"
echo "Building using ${BUILDER}"
echo "Version tags: ${TAGS[*]}"
echo "############################"
echo ""

mv "${APP_UNPACKED}" "${BINARY}"
chmod +x "${BINARY}"

cp "${HERE}/Containerfile" "${BUILD}/"

BUILD_ARGS=(--file "Containerfile")

for tag in "${TAGS[@]}"; do
    BUILD_ARGS+=(--tag "${TAG_BASE}:${tag}")
done

"${BUILDER}" build \
    "${BUILD_ARGS[@]}" \
    "${BUILD}"

if $PUSH; then

    echo "############################"
    echo " Pushing to remote registry"
    echo "############################"
    echo ""

    for t in "${TAGS[@]}"; do
        tag="${TAG_BASE}:${t}"
        echo "Pushing to remote registry: ${tag}"
       "${BUILDER}" push "${tag}"
    done

    if ! $FORCE && [ "${KNOWN_VERSION}" != "${VERSION}" ]; then
        # Update latest built version, if everything went well
        echo "KNOWN_VERSION=${VERSION}" > "${VERSION_FILE}"
    fi
fi
