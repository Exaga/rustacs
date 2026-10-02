#!/bin/bash

# Rust Administration & Control System - RUSTACS
#
# Automated Rust server log file serialisation and backup sequencing
#
# This script takes the active log file from the active Rust server and
# tarballs it into a backup directory with a timestamp in to the filename
# for easy auditing and retention management.
#
# It achieves this by copying the existing [live] active log file before 
# archiving it. Then truncates the existing active log so that [systemd]
# service can continue writing to it.
#
# This script can be automated to run from a crontab.
#
### IMPORTANT NOTE:
#
# The dot-env (.rustserver.env) file is a prerequisites for this script to 
# run. It needs to be present on the system with the correct permissions 
# beforehand.
#
### USAGE:
#
# Copy this script into a user directory - e.g. /home/rust/bin/
# Make the script executable:
#
#   chmod 770 /home/rust/bin/rustserverlogswap.sh
#
# Run the script
#
#   /home/rust/bin/rustserverlogswap.sh
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
BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_${RUST_SERVER_HOSTNAME}-rustserverbackup-log.tar.xz"
LOG_DIR="${RUST_LOGDIR}"
LOG_FILE="${LOG_DIR}/${PRGNAM}.log"

# Rust server active and moved log file names
RUNNING_LOG="${RUST_LOGDIR}/${RUST_SERVER_LOGFILE}.log"
SHIFTED_LOG="${RUST_LOGDIR}/${RUST_SERVER_LOGFILE}_${TIMESTAMP}.log"

# Archive log files larger than n MiB
LOGFILEMAXSIZE="${RUST_SERVER_MAX_LOGFILE}"
MAX_BYTES=$((LOGFILEMAXSIZE * 1024 * 1024))

# Progress log function
log() {
  printf "%(%F %T)T : %s: %s\\n" "-1" "${PRGNAM}" "${1}" 2>&1 | tee -a "${LOG_FILE}"
}

# Verify the file is active and evaluate the raw byte footprint
if [ -f "${RUNNING_LOG}" ] && [ "$(stat -c %s "${RUNNING_LOG}")" -ge "${MAX_BYTES}" ]; then

    # Copy running log file
    if ! cp -- "${RUNNING_LOG}" "${SHIFTED_LOG}"; then
        log "ERROR! - Copy failed! Log not truncated." >&2
        exit 1
    fi
    log "Copied $(basename "${RUNNING_LOG}") to $(basename "${SHIFTED_LOG}")..."

    # Truncate running log file
    if ! > "${RUNNING_LOG}"; then
        log "ERROR! - Unable to truncate $(basename "${RUNNING_LOG}")!" >&2
        exit 1
    fi
    log "Truncated $(basename "${RUNNING_LOG}")..."

    # Archive shifted log file
    if ! tar -cJf "${BACKUP_FILE}" -C "${RUST_LOGDIR}" "$(basename "${SHIFTED_LOG}")"; then
        log "ERROR! - Failed to archive $(basename "${SHIFTED_LOG}")!" >&2
        log "NOTE! Shifted log has been preserved: ${SHIFTED_LOG}"
        exit 1
    fi

    log "Created $(basename "${BACKUP_FILE}") tarball..."

    # Verify Rust server log archive integrity
    if ! tar -tJf "${BACKUP_FILE}" >/dev/null 2>&1; then
        log "ERROR! - $(basename "${BACKUP_FILE}") tarball integrity check failed!" >&2
        log "NOTE! Shifted log has been preserved: ${SHIFTED_LOG}"
        exit 1
    fi

    log "Verified $(basename "${BACKUP_FILE}") tarball integrity."

    # Remove shifted source only after archive has been verified
    if ! rm -f -- "${SHIFTED_LOG}"; then
        log "ERROR! - Unable to remove shifted log: ${SHIFTED_LOG}" >&2
        exit 1
    fi

    # Verify backup archive ownership
    if [ "$(stat -c '%U:%G' "${BACKUP_FILE}")" != "${RUST_USERNAME}:${RUST_USERGROUP}" ]; then
        if sudo -n /usr/bin/chown "${RUST_USERNAME}:${RUST_USERGROUP}" "${BACKUP_FILE}"; then
            log "NOTE! Reset permissions on ${BACKUP_FILE} to: ${RUST_USERNAME}:${RUST_USERGROUP}"
        else
            log "ERROR! - Unable to reset ownership on ${BACKUP_FILE}!" >&2
            exit 1
        fi
    fi

    log "######"
fi

# Done
exit 0

#EOF<*>