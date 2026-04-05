#!/usr/bin/env bash

set -euo pipefail

HERE="$(dirname "$(realpath "$0")")"
WORK_FOLDER="${HERE}/build"
SCRIPTS_FOLDER="${HERE}/scripts"

export WORKSPACE="${HERE}"
FORCE=false
PUSH=false

mkdir -p "${WORK_FOLDER}"

if [[ "$*" = *"--force"* ]]; then
    FORCE=true
fi

if [[ "$*" = *"--push"* ]]; then
    PUSH=true
fi

if ! $FORCE && ! "${SCRIPTS_FOLDER}/remote.sh" check-version; then
    echo "Remote version equals the local"
    exit 0
fi

VERSION="$("${SCRIPTS_FOLDER}/remote.sh" get-version)"

"${SCRIPTS_FOLDER}/remote.sh" get-archives "${WORK_FOLDER}"

"${SCRIPTS_FOLDER}/build_images.sh" "${VERSION}" "${WORK_FOLDER}" "${WORK_FOLDER}/"*.zip

if $PUSH; then
    "${SCRIPTS_FOLDER}/build_images.sh" "${VERSION}" --push
    # Save the version, if we made it this far
    "${SCRIPTS_FOLDER}/remote.sh" get-version save
fi
