#!/bin/bash

# Rust Administration & Control System - RUSTACS
#
# Automated transactional backup script for Rust server
#
# 2026-09-23 - v1.0.1   [release version]
#
# This script performs a backup of specific Rust server world state data 
# files and creates a xz archive - saved to a backup directory. It sources
# a dot-env file to load settings and path variables. It uses rustacs to 
# output server maintenance notices on a 30 minute countdown to apprise any
# online players of the scheduled Rust server shutdown and restart. If the 
# Rust server is inactive it skips to the backup process without any alert 
# notices being sent. This script also creates a log with entries of the 
# backup process including any errors/failures.
#
### IMPORTANT NOTES:
#
# The dot-env (.rustserver.env) file and rustacs (Python3) wrapper script
# are prerequisites for this script to run. Both need to be present on the
# system - rustacs must have the correct permissions beforehand.
#
### USAGE:
#
# Copy this script into a user directory - e.g. /home/rust/bin/
# Make the script executable:
#
#   chmod 770 /home/rust/bin/rustserverbackup.sh
#
# Run the script
#
#   /home/rust/bin/rustserverbackup.sh
#
# This script can be automated to run from a crontab.
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
DATA_DIR="${RUST_SERVER_FILEDIR}/${RUST_SERVER_ID}"
BACKUP_DIR="${RUST_BACKUP_DIR}"
TIMESTAMP=$(date '+%F-%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/${RUST_SERVER_ID}-backup_${TIMESTAMP}.tar.xz"
LOG_DIR="${RUST_LOGDIR}"
LOG_FILE="${LOG_DIR}/${PRGNAM}.log"

# Purge backup archive files older than n DAYS
ARCHIVE_AGE="63"

# Progress log function
log() {
  printf "%(%F %T)T : %s: %s\\n" "-1" "${PRGNAM}" "${1}" 2>&1 | tee -a "${LOG_FILE}"
}

# Verification check
if [ ! -d "${DATA_DIR}" ]; then
    log "ERROR! - Target data directory ${DATA_DIR} not found! " >&2
    exit 1
fi

# Ensure backup directory exists
if ! mkdir -p "${BACKUP_DIR}"; then
    log "ERROR! - Unable to create backup directory: ${BACKUP_DIR}" >&2
    exit 1
fi

# Verify rustacs is present before executing warnings
if [ ! -x "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" ]; then
    log "ERROR! - ${RUSTACS_PATH} not found or not executable!" >&2
    exit 1
fi

# Check server active state to decide on warning messages (or not)
RUSTSERVER_STATE="$(sudo /usr/bin/systemctl is-active rustserver.service)"

if [ "${RUSTSERVER_STATE}" = "active" ]; then
    log "Initiating active Rust server backup notices..."
    RUSTSERVER_ACTIVE=1
    log "Commencing backup countdown. T-minus 30 minutes and counting ..."

    # Broadcast 30-minute backup notice
    "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" say ": Maintenance scheduled in 30 minutes. Server will be restarting!"
    sleep 900

    # Broadcast 15-minute backup notice
    "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" say ": Maintenance scheduled in 15 minutes. Server will be restarting!"
    sleep 600

    # Broadcast 5-minute backup notice
    "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" say ": Maintenance scheduled in 5 minutes. Server will be restarting!"
    sleep 270

    # Broadcast imminent 30 second backup warning
    "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" say "WARNING! Shutting down for maintenance in 30 seconds and restarting. Secure your loot!"

    # RUSTACS server.save
    if ! "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" server.save; then
        log "ERROR! - Rust server save command failed! Aborting backup..." >&2
        exit 1
    fi
    log "${RUSTACS_PATH} server.save ..."

    sleep 30

    # Final broadcast notice
    "${RUSTACS_PATH:?RUSTACS_PATH is not set in dot-env}" say ": The hydrated ferric oxide will be with you. Always"

    log "Stopping rustserver.service via systemd..."
    if ! sudo /usr/bin/systemctl stop rustserver.service; then
        log "ERROR! - Failed to stop rustserver.service!" >&2
        exit 1
    fi

elif [ "${RUSTSERVER_STATE}" = "inactive" ]; then
    RUSTSERVER_ACTIVE=0
    log "Rust server service state is inactive. Launching backup archive process..."

elif [ "${RUSTSERVER_STATE}" = "failed" ]; then
    RUSTSERVER_ACTIVE=0
    log "Rust server service state is failed. Launching backup archive process..."

else
    log "ERROR! - Unexpected Rust server service state: ${RUSTSERVER_STATE}. Aborting backup..." >&2
    exit 1
fi

# Backup specific Rust server data to xz archive
log "Archiving Rust server state data files..."
(cd "${DATA_DIR}" && tar -cvJf "${BACKUP_FILE}" --ignore-failed-read -- \
  cfg/ loadouts/ serveremoji/ companion.id relationship.*.db \
  player.*.db clans.*.db sv.files.*.db *.sav* *.map*)

# Create log entry of backup archive status
TAR_STATUS=$?
if [ "${TAR_STATUS}" -eq 0 ]; then
    log "Archive created -> ${BACKUP_FILE}"
    log "Archive file size is $(du -sh "${BACKUP_FILE}" | awk '{print $1}')"
else
    log "ERROR! - Archiving Rust server state files encountered a terminal failure and exited with error code: [${TAR_STATUS}]" >&2

    if [ "${RUSTSERVER_ACTIVE}" -eq 1 ]; then
        log "Restarting rustserver.service via systemd..."
        if ! sudo /usr/bin/systemctl start rustserver.service; then
            log "ERROR! - Failed to start rustserver.service!" >&2
        fi
    fi

    exit 1
fi

# Verify ownership of backup archive
PRGNAM_USER="$(id -un)"
if [ "${PRGNAM_USER}" != "${RUST_USERNAME}" ]; then
    log "WARNING! Rust server backup process was run by '${PRGNAM_USER}' user..."

    if sudo /usr/bin/chown "${RUST_USERNAME}:${RUST_USERGROUP}" "${BACKUP_FILE}"; then
        log "> Set file ownership of $(basename "${BACKUP_FILE}") to: ${RUST_USERNAME}:${RUST_USERGROUP}"
    else
        log "ERROR! - Unable to set ownership on $(basename "${BACKUP_FILE}")!" >&2
        exit 1
    fi
fi

# Restart Rust server [systemd] service
if [ "${RUSTSERVER_ACTIVE}" -eq 1 ]; then
    log "Starting game server engine via systemd..."
    if ! sudo /usr/bin/systemctl start rustserver.service; then
        log "ERROR! - Failed to start rustserver.service!" >&2
        exit 1
    fi
fi

# Purge backup archive files older than n days
log "Conducting backup archive file housekeeping..."
find "${BACKUP_DIR}" -name "${RUST_SERVER_ID}-backup_*.tar.xz" -type f -mtime +"${ARCHIVE_AGE}" -print -delete | while read -r deleted; do
    log "Deleted backup archive older than ${ARCHIVE_AGE} days -> ${deleted}"
done

# Done
log "Process completed successfully!"
log "######"
exit 0

#EOF<*>