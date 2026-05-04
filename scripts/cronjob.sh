#!/usr/bin/env bash

# This scripts can be used for running cron jobs

set -euo pipefail

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"
SCAN_OUTPUT="${WORKSPACE}/build/scan"

SENDER=""
BUILD=false
SCAN=false
EMAIL=""
ALWAYS=false

usage() {
    echo """
  Usage: ${0} action [<option>..]
  It can send an email after the action, provided that local mail delivery is correctly set up
  
  Actions:
    build              Build images, of new version available
    scan               Scan for security vulnerabilities of last built version
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

EMAIL_ARGS=(-A "${LOG_FILE}")

rm -rf "${SCAN_OUTPUT}"
mkdir -p "${SCAN_OUTPUT}"

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

send_email() {
    local subject="${1}"
    local body="${2}"
    shift 2
    local args=(-s "${subject}" "${EMAIL_ARGS[@]}")
    if [ -n "${SENDER}" ]; then
        args+=("-aFrom:${SENDER}")
    fi
    echo -e "${body}" | mail "${args[@]}" "${EMAIL}"
}

prev_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"

if $BUILD; then
    "${WORKSPACE}/build.sh" build --push 2>&1 | tee "${LOG_FILE}"
    new_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"
    if [ "${prev_version}" != "${new_version}" ]; then
        log_message="Sending update mail to ${EMAIL}"
        subject="New IHC Captain image built: ${prev_version} -> ${new_version}"
        body="${UPDATED_BODY}"
    elif $ALWAYS; then
        log_message="Sending noop mail to ${EMAIL}"
        subject="IHC Captain image unchanged: ${prev_version}"
        body="${NOOP_BODY}"
    fi
elif $SCAN; then
    body="${SCANNED_BODY}"
    image="$("${WORKSPACE}/scripts/build_images.sh" "${prev_version}" --get-tag)"
    if ! "${WORKSPACE}/scripts/scan.sh" "${SCAN_OUTPUT}" "${image}" 2>&1 | tee "${LOG_FILE}"; then
        log_message="Sending scanned mail to ${EMAIL}"
        subject="IHC Captain vulnerability found for image: ${image}"
        while read -r report; do
            EMAIL_ARGS+=(-A "${report}")
        done < <(find "${SCAN_OUTPUT}/" -name "*.html")
    elif $ALWAYS; then
        log_message="Sending scanned mail to ${EMAIL}"
        subject="IHC Captain image scanned: ${image}"
    fi
else
    echo "Unknown command: ${COMMAND}"
    exit 1
fi

if [ -z "${EMAIL}" ]; then
    exit 0
fi

if [ -n "${log_message:-}" ]; then
    echo "${log_message}"
    send_email "${subject}" "${body}"
fi
