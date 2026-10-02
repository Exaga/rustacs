#!/bin/bash

# Rust Administration & Control System - RUSTACS
#
# RustDedicated update detection and controlled update handler
#
# This script checks the locally installed RustDedicated Steam build ID
# against the current public Steam build ID. If both build IDs match, no
# action is taken. If a newer public build is detected, the script reports
# the update and can restart an active RustDedicated server through its
# systemd service. The service unit performs the RustDedicated update through
# SteamCMD before the server is started again.
#
# This script does not use a third-party API to determine the current public
# RustDedicated build. The remote build ID is obtained directly through
# SteamCMD app-info for Steam App ID 258550.
#
# This script can be automated to run from a crontab.
#
### IMPORTANT NOTES:
#
# The dot-env (.rustserver.env) file and RustDedicated Steam appmanifest are
# prerequisites for this script to run. SteamCMD must also be installed and
# available at /usr/games/steamcmd.
#
# An active RustDedicated server is restarted only when a different public
# Steam build ID is detected. An inactive server is NOT started automatically.
# The available update is reported and will be installed by the service unit
# the next time the server is started.
#
### USAGE:
#
# Copy this script into a user directory - e.g. /home/rust/bin/
# Make the script executable:
#
#   chmod 770 /home/rust/bin/rustdedicatedupdate.sh
#
# Run the script
#
#   /home/rust/bin/rustdedicatedupdate.sh
#
### MIT License:
#
# Copyright 2026 Exaga - penthux.net
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
###

# Load Rust server .env settings
. /home/rust/.rustacs/.rustserver.env

# Variables
PRGNAM="$(basename "${BASH_SOURCE[0]}" .sh)"
STEAMCMD="${STEAMCMD_PATH}"
STEAM_APP_ID="258550"
MANIFEST="${RUST_INSTALL_WORKDIR}/steamapps/appmanifest_${STEAM_APP_ID}.acf"
SERVICE_UNIT="$(basename "${RUST_SERVICE_PATH}")"
LOG_DIR="${RUST_LOGDIR}"
LOG_FILE="${LOG_DIR}/${PRGNAM}.log"

# Progress log function
log() {
    printf "%(%F %T)T : %s: %s\\n" "-1" "${PRGNAM}" "${1}" 2>&1 | tee -a "${LOG_FILE}"
}

# Get locally installed RustDedicated Steam build ID
get_local_build() {
    awk -F'"' '/"buildid"/ { print $4; exit }' "${MANIFEST}"
}

# Get current public RustDedicated Steam build ID
get_remote_build() {
    "${STEAMCMD}" \
        +login anonymous \
        +app_info_update 1 \
        +app_info_print "${STEAM_APP_ID}" \
        +quit 2>/dev/null |
    awk '
        /"public"/ { public_branch=1 }
        public_branch && /"buildid"/ {
            gsub(/"/, "", $2)
            print $2
            exit
        }
    '
}

# Verify RustDedicated Steam appmanifest exists
if [ ! -r "${MANIFEST}" ]; then
    log "ERROR! - RustDedicated Steam appmanifest not found or not readable: ${MANIFEST}" >&2
    exit 1
fi

# Verify SteamCMD is available
if [ ! -x "${STEAMCMD}" ]; then
    log "ERROR! - SteamCMD executable not found: ${STEAMCMD}" >&2
    exit 1
fi

# Read local and current public RustDedicated Steam build IDs
LOCAL_BUILD="$(get_local_build)"
REMOTE_BUILD="$(get_remote_build)"

# Verify build IDs were obtained successfully
if ! [[ "${LOCAL_BUILD}" =~ ^[0-9]+$ ]]; then
    log "ERROR! - Unable to determine local RustDedicated Steam build ID!" >&2
    exit 1
fi

if ! [[ "${REMOTE_BUILD}" =~ ^[0-9]+$ ]]; then
    log "ERROR! - Unable to determine current public RustDedicated Steam build ID!" >&2
    exit 1
fi

log "Local RustDedicated Steam build: ${LOCAL_BUILD}"
log "Public RustDedicated Steam build: ${REMOTE_BUILD}"

# Nothing to do when local and public Steam build IDs match
if [ "${LOCAL_BUILD}" = "${REMOTE_BUILD}" ]; then
    log "RustDedicated is up to date."
    log "######"
    exit 0
fi

log "IMPORTANT! - RustDedicated update detected: ${LOCAL_BUILD} -> ${REMOTE_BUILD}"

# Determine current RustDedicated service state
RUSTSERVER_STATE="$(sudo /usr/bin/systemctl is-active "${SERVICE_UNIT}")"

case "${RUSTSERVER_STATE}" in
    active)
        log "RustDedicated server is active. Restarting ${SERVICE_UNIT} to apply update..."

        if ! sudo /usr/bin/systemctl restart "${SERVICE_UNIT}"; then
            log "ERROR! - Unable to restart ${SERVICE_UNIT}!" >&2
            exit 1
        fi

        # Re-read local build ID after systemd ExecStartPre has run SteamCMD
        LOCAL_BUILD="$(get_local_build)"

        if [ "${LOCAL_BUILD}" != "${REMOTE_BUILD}" ]; then
            log "ERROR! - RustDedicated update verification failed! Local build is ${LOCAL_BUILD}; expected ${REMOTE_BUILD}." >&2
            exit 1
        fi

        log "RustDedicated updated successfully to Steam build ${LOCAL_BUILD}."
        ;;

    inactive|failed)
        log "RustDedicated server is ${RUSTSERVER_STATE}. Update available but server will not be started automatically."
        log "Steam build ${REMOTE_BUILD} will be installed by ${SERVICE_UNIT} when the server is next started."
        ;;

    *)
        log "ERROR! - Unexpected RustDedicated service state: ${RUSTSERVER_STATE}" >&2
        exit 1
        ;;
esac

# Done
log "Process completed successfully!"
log "######"
exit 0

#EOF<*>
