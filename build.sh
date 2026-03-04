#!/usr/bin/env bash

TAG_BASE="zimagedk/ihccaptain"

# Change to none-beta when released
DOWNLOAD_URL_BASE="https://jemi.dk/ihc/beta/download.php?file="
# Determine latest automatically
RELEASE_FILE="IHCCaptain_2.0.1_linux-x64_20260303-0824.zip"
SUPPLIED_FILE=""

HERE="$(dirname "$(realpath $0)")"
BUILD="${HERE}/build"
BINARY="${BUILD}/goihccap"
PUSH=false

rm -rf "${BUILD}"
mkdir -p "${BUILD}"

while [ -n "${1:-}" ]; do
    if [ "${1}" = "--push" ]; then
        PUSH=true
        shift
    elif [ -r "${1}" ]; then
        SUPPLIED_FILE="${1}"
        shift
    fi
done

if [ -n "${SUPPLIED_FILE}" ]; then
    RELEASE_FILE="${SUPPLIED_FILE}"
else
    curl -get "${DOWNLOAD_URL_BASE}${RELEASE_FILE}" --output "/tmp/${RELEASE_FILE}"
    RELEASE_FILE="/tmp/${RELEASE_FILE}"
    trap rm "'/tmp/${RELEASE_FILE}'" EXIT
fi

unzip -nq -d "${BUILD}" "${RELEASE_FILE}"

readarray -t APPS_UNPACKED < <(ls -1 "${BUILD}")

if [ "${#APPS_UNPACKED[@]}" -ne 1 ]; then
    echo "Archive should contain exactly one file, but found: ${APPS_UNPACKED[*]}"
    exit 1
fi

APP_UNPACKED="${BUILD}/${APPS_UNPACKED[0]}"

if ! file "${APP_UNPACKED}" | grep -q "executable.*x86-64"; then
    echo "Unpacked file $(basename "${APP_UNPACKED}") is not a 64-bit executable"
    exit 1
fi

VERSION="$(echo "${RELEASE_FILE}" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")"
MAJOR="$(echo "${VERSION}" | grep -oE "^[0-9]+")"
MINOR="$(echo "${VERSION}" | grep -oE "^[0-9]+\.[0-9]+")"
LABEL="$(echo "${RELEASE_FILE}" | grep -oE "[0-9]+-[0-9]+")"

# ARGS=(build)
# if which buildah >/dev/null; then
#     BUILDER=buildah
# elif which podman >/dev/null; then
#     BUILDER=podman
# elif which docker >/dev/null; then
    BUILDER=docker
# else
#     echo "No builder found, please install builah, podman or docker"
#     exit 1
# fi

echo ""
echo "Building using ${BUILDER}"
echo ""
echo "Version tags: $MAJOR, $MINOR, $VERSION, ${VERSION}-$LABEL"
echo ""

mv "${APP_UNPACKED}" "${BINARY}"
chmod +x "${BINARY}"

cp "${HERE}/Dockerfile" "${BUILD}/"

"${BUILDER}" build \
    --tag "${TAG_BASE}:${MAJOR}" \
    --tag "${TAG_BASE}:${MINOR}" \
    --tag "${TAG_BASE}:${VERSION}" \
    --tag "${TAG_BASE}:${VERSION}-${LABEL}" \
    --tag "${TAG_BASE}:latest" \
    "${BUILD}"

if $PUSH; then
    # ID="$(docker images --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep "${TAG_BASE}:latest" | awk '{print $1}')"
    # docker push --all-tags "${ID}"
    docker push "${TAG_BASE}:${MAJOR}"
    docker push "${TAG_BASE}:${MINOR}"
    docker push "${TAG_BASE}:${VERSION}"
    docker push "${TAG_BASE}:${VERSION}-${LABEL}"
    docker push "${TAG_BASE}:latest"
fi
