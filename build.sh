#!/usr/bin/env bash

set -euo pipefail

HERE="$(dirname "$(realpath "$0")")"
WORK_FOLDER="${HERE}/build"
SCRIPTS_FOLDER="${HERE}/scripts"

export WORKSPACE="${HERE}"
BUILD=false
FORCE=false
PUSH=false
LOCAL=false

mkdir -p "${WORK_FOLDER}"

usage() {
    echo """
  Usage: ${0} build <option>
  Options:
    --push                       Push the image to remote registry, if build was successful
    --force                      Don't compare local and remote versions, just fetch latest and build
    --local                      Don't check for updates or fetch binaries
    """
}

while [ -n "${1:-}" ]; do
    case "${1}" in
    build)
        BUILD=true
        ;;
    --force)
        FORCE=true
        ;;
    --push)
        PUSH=true
        ;;
    --local)
        LOCAL=true
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    esac
    shift
done

if ! $BUILD; then
    echo "Build command not provided"
    usage
    exit 1
fi

if ! $LOCAL; then
    if ! $FORCE && ! "${SCRIPTS_FOLDER}/remote.sh" check-version; then
        echo "Remote version equals the local"
        exit 0
    fi

    VERSION="$("${SCRIPTS_FOLDER}/remote.sh" get-version)"

    "${SCRIPTS_FOLDER}/remote.sh" get-archives "${WORK_FOLDER}"
else
    VERSION="$("${SCRIPTS_FOLDER}/remote.sh" known-version)"
fi

if ! find "${WORK_FOLDER}" -name "*.zip" | grep -q zip; then
    echo "No archives found in ${WORK_FOLDER}"
    exit 1
fi

"${SCRIPTS_FOLDER}/build_images.sh" "${VERSION}" "${WORK_FOLDER}" "${WORK_FOLDER}/"*.zip

if $PUSH; then
    "${SCRIPTS_FOLDER}/build_images.sh" "${VERSION}" --push
fi

if ! $LOCAL; then
    if $PUSH || $FORCE; then
        # Save the version, if we made it this far
        "${SCRIPTS_FOLDER}/remote.sh" get-version save
    fi
fi
