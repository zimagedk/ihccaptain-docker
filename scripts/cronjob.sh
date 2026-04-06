#!/usr/bin/env bash

set -euo pipefail

WORKSPACE="$(dirname "$(dirname "$(realpath "$0")")")"

EMAIL=""
ALWAYS=false

usage() {
    echo """
  Usage: ${0} [<option>..]
  It can send an email after build, provided that local mail delivery is correctly set up
  Options:
    --email            Email address to send the build result to in case of new version built
    --always           Always send email; not only on new build
    """
}

while [ -n "${1:-}" ]; do
    case "${1}" in
    --email)
        EMAIL="${2}"
        shift
        ;;
    --always)
        ALWAYS=true
        ;;
    esac
    shift
done

TEMP_DIR="$(mktemp -d)"
LOG_FILE="${TEMP_DIR}/build.log"

leaving() {
    rm -rf "${TEMP_DIR}"
}

UPDATED_SUBJECT="New IHC Captain image built"

UPDATED_BODY="""

A new IHC Captain image was built.
See attached log file.

"""

NOOP_SUBJECT="IHC Captain image unchanged"

NOOP_BODY="""

No new IHC Captain image was built.

"""

send_email() {
    local subject="${1}"
    local body="${2}"
    echo -e "${body}" | mail -s "${subject}" \
        --attach "${LOG_FILE}" \
        "${EMAIL}"
}

prev_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"

"${WORKSPACE}/build.sh" build --push 2>&1 | tee "${LOG_FILE}"

new_version="$("${WORKSPACE}/scripts/remote.sh" known-version)"

if [ -z "${EMAIL}" ]; then
    exit 0
fi

if [ "${prev_version}" != "${new_version}" ]; then
    echo "Sending update mail to ${EMAIL}"
    send_email "${UPDATED_SUBJECT}: ${prev_version} -> ${new_version}" "${UPDATED_BODY}"
elif $ALWAYS; then
    echo "Sending noop mail to ${EMAIL}"
    send_email "${NOOP_SUBJECT}: ${prev_version}" "${NOOP_BODY}"
fi
