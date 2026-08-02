#!/usr/bin/env bash

# This scripts can be used for running cron jobs

set -euo pipefail

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
SCAN_OUTPUT="${WORKSPACE}/build/scan"

SENDER=""
BUILD=false
BUILD_FORCE=false
SCAN=false
EMAIL=""
ALWAYS=false
SEND_EMAIL=false

usage() {
    echo """
  Usage: ${0} action [<option>..]
  It can send an email after the action, provided that local mail delivery is correctly set up
  
  Actions:
    build              Build images, of new version available
    scan               Scan for security vulnerabilities of last built version
                       and build new version if issue found and new alpine is available
  Options:
    --email            Email address to send the build result to in case of new version built
    --sender <address> Senders email address
    --always           Always send email; not only on new build
    """
}

TEMP_DIR="$(mktemp -d)"

COMMAND="${1:-}"

while [ -n "${1:-}" ]; do
    case "${1}" in
    build)
        BUILD=true
        LOG_FILE="${TEMP_DIR}/build.log"
        ;;
    scan)
        SCAN=true
        LOG_FILE="${TEMP_DIR}/scan.log"
        ;;
    --force)
        BUILD_FORCE=true
        ;;
    --email)
        EMAIL="${2}"
        shift
        ;;
    --sender)
        SENDER="${2}"
        shift
        ;;
    --always)
        ALWAYS=true
        ;;
    esac
    shift
done

if [ -z "${COMMAND}" ]; then
    echo "No action provided"
    usage
    exit 1
fi

EMAIL_ARGS=(-A "${LOG_FILE}")

rm -rf "${SCAN_OUTPUT}"
mkdir -p "${SCAN_OUTPUT}"

known_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"

leaving() {
    rm -rf "${TEMP_DIR}"
}

SCANNED_BODY="""

The image vas scanned, see attached log for result

"""

UPDATED_BODY="""

A new IHC Captain image was built.
See attached log file.

"""

NOOP_BODY="""

No new IHC Captain image was built.

"""

log() {
    echo "$(date --iso-8601=seconds) $*"
}

send_email() {
    local subj="${1}"
    local body="${2}"
    shift 2
    local args=(-s "${subj}" "${EMAIL_ARGS[@]}")
    if [ -n "${SENDER}" ]; then
        args+=("-aFrom:${SENDER}")
    fi
#    echo "#### SEND EMAIL DUMMY #### subject=${subj}"
    echo -e "${body}" | mail "${args[@]}" "${EMAIL}"
}

log_and_send_email() {
    if [ -n "${log_message:-}" ]; then
        log "${log_message}"
    fi
    if $SEND_EMAIL && [ -n "${EMAIL}" ]; then
        send_email "$@"
    fi
}

build() {
    log "Starting IHC Captain Image build"
    build_args=(build --push)
    build_args=(build)
    if $BUILD_FORCE; then
        build_args+=(--force)
    fi
    "${WORKSPACE}/build.sh" "${build_args[@]}" 2>&1 | tee "${LOG_FILE}"
    new_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"
    if $BUILD_FORCE || [ "${known_version}" != "${new_version}" ]; then
        SEND_EMAIL=true
        log_message="Sending update mail to ${EMAIL}"
        log_and_send_email "New IHC Captain image built: ${known_version} -> ${new_version}" "${UPDATED_BODY}"
    elif $ALWAYS; then
        SEND_EMAIL=true
        log_message="Sending noop mail to ${EMAIL}"
        log_and_send_email "IHC Captain image unchanged: ${known_version}" "${NOOP_BODY}"
    fi
}

scan() {
    log "Starting IHC Captain Image scan"
    body="${SCANNED_BODY}"
    image="$("${WORKSPACE}/scripts/build_images.sh" latest-tag)"

    if ! "${WORKSPACE}/scripts/scan.sh" "${SCAN_OUTPUT}" "${image}" 2>&1 | tee "${LOG_FILE}"; then

        while read -r report; do
            EMAIL_ARGS+=(-A "${report}")
        done < <(find "${SCAN_OUTPUT}" -name "*.html")

        log_message="Sending scanned mail to ${EMAIL}"
        log_and_send_email "IHC Captain vulnerability found for image: ${image}" "${body}"

        local_version="$("${WORKSPACE}/scripts/build_images.sh" alpine-version-local)"
        remote_version="$("${WORKSPACE}/scripts/build_images.sh" alpine-version-remote)"

        if [ "${local_version}" != "${remote_version}" ]; then
            return 1
        fi
    elif $ALWAYS; then
        log_message="Sending scanned mail to ${EMAIL}"
        log_and_send_email "IHC Captain image scanned: ${image}" "${body}"
    fi
}

rebuild() {
    args=(build --force)
    [ -z "${EMAIL}" ] || args+=(--email "${EMAIL}")
    [ -z "${SENDER}" ] || args+=(--sender "${SENDER}")
    if $ALWAYS; then
        args+=(--always)
    fi
    exec $0 "${args[@]}"
}

if $BUILD; then
    build
    exit $?
elif $SCAN; then
    if ! scan; then
        rebuild
    fi
else
    echo "Unknown command: ${COMMAND}"
    exit 1
fi
