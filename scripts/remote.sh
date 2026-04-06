#!/usr/bin/env bash

set -euo pipefail

# Change to none-beta when released
GET_VERSION_URL="https://jemi.dk/ihc/beta/update.php"
UPDATE_CHECK_URL="${GET_VERSION_URL}?v=0.0.0&os=linux&arch=@ARCH@"

if [ -z "${WORKSPACE:-}" ]; then
    WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
fi

ACTION="${1:-}"
FOLDER="${2:-}"

VERSION_FILE="${WORKSPACE}/.latest_version"
KNOWN_VERSION="0.0.0"

CHECK_VERSION=false
GET_VERSION=false
SAVE_VERSION=false
GET_ARCHIVES=false

if [ -r "${VERSION_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${VERSION_FILE}"
fi

error() {
    echo "$*" 1>&2
}

usage() {
    echo """
  Usage: ${0} <command> <options>
  Commands:
    known-version                   Return the current known version
    check-version                   Checks if there's a new version remote
    get-version <save>              Get the remote version
    get-archives <download-folder>  Get archives for current version
    """
}

get_remote_version() {
    curl --get --fail --no-progress-meter "${GET_VERSION_URL}" | jq -r '.latest_version'
}

get_release_file() {
    local arch="${1:-}"
    local url="${UPDATE_CHECK_URL}"
    local file

    echo "Fetching binary: ${arch}"

    url="${url/@ARCH@/$arch}"

    json="$(curl --get --fail --no-progress-meter "${url}" 2>&1)"

    if [ "$(jq -r '.update_available' <<< "${json}")" != "true" ]; then
        exit 1
    fi

    url="$(jq -r '.url' <<< "${json}")"
    file="${FOLDER}/$(echo "${url}" | grep -oE "[^=]*$")"

    curl --get --fail --no-progress-meter --output "${file}" "${url}" 2>&1
}

case "${ACTION}" in
    known-version)
        echo "${KNOWN_VERSION}"
        exit 0
    ;;
    check-version)
        CHECK_VERSION=true
    ;;
    get-version)
        GET_VERSION=true
        if [ "${FOLDER}" = "save" ]; then
            SAVE_VERSION=true
        fi
    ;;
    get-archives)
        GET_ARCHIVES=true
    ;;
    *)
        error "No or unknown action '${ACTION}'"
        usage 
        exit 1
    ;;
esac

if $CHECK_VERSION; then
    ver="$(get_remote_version)"
    if [ -z "${ver}" ] || [ "${ver}" = "${KNOWN_VERSION}" ]; then
        exit 1
    fi
    echo "Found update remote: ${ver}"
    exit 0
fi

if $GET_VERSION; then
    ver="$(get_remote_version)"
    if $SAVE_VERSION; then
        echo "KNOWN_VERSION=${ver}" > "${VERSION_FILE}"
    else
        echo "${ver}"
    fi
    exit 0
fi

if $GET_ARCHIVES; then

    if [ -z "${FOLDER}" ] || [ ! -d "${FOLDER}" ]; then
        error "Work folder must be a folder"
        exit 1
    fi

    find "${FOLDER}" -maxdepth 1 -name "*.zip" -exec rm -f {} \;

    get_release_file "amd64"
    get_release_file "arm64"
fi
