#!/bin/bash

# Rust Administration & Control System - RUSTACS
#
# Create a brand new Rust server game world map
#
# This script creates a new Rust server game world, generating a map based
# on the seed specified in the dot-env file. It does not replace or delete
# any existing Rust server files. It does NOT remove or overwrite player 
# blueprints. Those are safe from being deleted by running this script.
#
# NB: The relevant Rust server files will be updated after this script has
# been executed, and the service has been started.
#
# This script is designed to run manually or as part of a planned schedule
# for server wipes, etc.
#
# This script can be automated to run from a crontab.
#
### IMPORTANT NOTES:
#
# This script is change-driven. If the settings in dot-env and the Rust 
# server service unit match this script is idempotent.
#
# This script WILL NOT execute if the Rust server is currently active! It
# MUST be stopped and the Rust server service MUST be inactive.
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
#   chmod 770 /home/rust/bin/rustservergenesys.sh
#
# Run the script
#
#   /home/rust/bin/rustservergenesys.sh
#
# Generate a new random map seed
#
#   /home/rust/bin/rustservergenesys.sh +newmap
#
# Set a specific map seed
#
#   /home/rust/bin/rustservergenesys.sh +seed 123456789
#
# Set a specific world size
#
#   /home/rust/bin/rustservergenesys.sh +size 6000
#
# Options can be combined in either order:
#
#   /home/rust/bin/rustservergenesys.sh +newmap +size 6000
#   /home/rust/bin/rustservergenesys.sh +size 6000 +seed 123456789
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
RUST_ENV="${RUST_SERVER_ENV}"
MASTER_CONFIG="${RUST_MASTER_CONFIG}"
RUST_SERVICE="${RUST_SERVICE_PATH}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
WORLD_BACKUP_DIR="${RUST_BACKUP_DIR}/worldbackups"
WORLD_BACKUP="${WORLD_BACKUP_DIR}/${RUST_SERVER_SEED}.${RUST_SERVER_WORLDSIZE}_${TIMESTAMP}.world"
LOG_DIR="${RUST_LOGDIR}"
LOG_FILE="${LOG_DIR}/${PRGNAM}.log"

# Progress log function
log() {
    printf "%(%F %T)T : %s: %s\\n" "-1" "${PRGNAM}" "${1}" 2>&1 | tee -a "${LOG_FILE}"
}

# Command usage function
usage() {
    cat <<EOF
Usage:
  ${PRGNAM}.sh
  ${PRGNAM}.sh +newmap
  ${PRGNAM}.sh +newmap [+size <value>]
  ${PRGNAM}.sh +seed <value> [+size <value>]
  ${PRGNAM}.sh +size <value>

Options:
  +newmap          Generate a new random map seed
  +seed <value>    Set a specific map seed (0-2147483647)
  +size <value>    Set the map world size (1000-6000)
  --help           Show this help

Examples:
  ${PRGNAM}.sh +newmap
  ${PRGNAM}.sh +newmap +size 6000
  ${PRGNAM}.sh +seed 123456789
  ${PRGNAM}.sh +seed 123456789 +size 6000
  ${PRGNAM}.sh +size 4500
EOF
}

# Set ownership of Rust config files function
rust_config_ownership() {
    if ! sudo -n /usr/bin/chown "${RUST_USERNAME}:${RUST_USERGROUP}" "${MASTER_CONFIG}"; then
        log "ERROR! - Unable to set ownership on $(basename "${MASTER_CONFIG}")!" >&2
        return 1
    fi

    if ! sudo -n /usr/bin/chown "${RUST_USERNAME}:${RUST_USERGROUP}" "${RUST_ENV}"; then
        log "ERROR! - Unable to set ownership on $(basename "${RUST_ENV}")!" >&2
        return 1
    fi
}

# Command syntax error function
usage_error() {
    printf "ERROR! - %s\n\n" "${1}" >&2
    usage >&2
    exit 1
}

# Update a setting in Rust server master config
update_master_setting() {
    local setting="${1}"
    local value="${2}"
    local tmp_file

    tmp_file="$(mktemp "${MASTER_CONFIG}.XXXXXX")" || return 1

    if ! awk -v setting="${setting}" -v value="${value}" '
        BEGIN { found = 0 }
        $0 ~ "^" setting "=" {
            print setting "=" value
            found = 1
            next
        }
        { print }
        END {
            if (!found)
                print setting "=" value
        }
    ' "${MASTER_CONFIG}" > "${tmp_file}"; then
        rm -f -- "${tmp_file}"
        return 1
    fi

    if ! chmod --reference="${MASTER_CONFIG}" "${tmp_file}" ||
       ! chown --reference="${MASTER_CONFIG}" "${tmp_file}" 2>/dev/null ||
       ! mv -- "${tmp_file}" "${MASTER_CONFIG}"; then
        rm -f -- "${tmp_file}"
        return 1
    fi
}

# Parse command options
NEW_MAP=0
NEW_SEED=""
NEW_SIZE=""

while [ "$#" -gt 0 ]; do
    case "${1}" in
        --help)
            if [ "$#" -ne 1 ]; then
                usage_error "--help cannot be combined with other options."
            fi
            usage
            exit 0
            ;;
        +newmap)
            if [ "${NEW_MAP}" -eq 1 ]; then
                usage_error "+newmap was specified more than once."
            fi
            NEW_MAP=1
            shift
            ;;
        +seed)
            if [ -n "${NEW_SEED}" ]; then
                usage_error "+seed was specified more than once."
            fi
            if [ "$#" -lt 2 ] || [[ "${2}" == +* ]] || [ "${2}" = "--help" ]; then
                usage_error "+seed requires a value."
            fi
            NEW_SEED="${2}"
            shift 2
            ;;
        +size)
            if [ -n "${NEW_SIZE}" ]; then
                usage_error "+size was specified more than once."
            fi
            if [ "$#" -lt 2 ] || [[ "${2}" == +* ]] || [ "${2}" = "--help" ]; then
                usage_error "+size requires a value."
            fi
            NEW_SIZE="${2}"
            shift 2
            ;;
        *)
            usage_error "Unknown option: ${1}"
            ;;
    esac
done

# Validate command options before changing master.config
if [ "${NEW_MAP}" -eq 1 ] && [ -n "${NEW_SEED}" ]; then
    usage_error "+newmap and +seed cannot be used together."
fi

if [ -n "${NEW_SEED}" ]; then
    if ! [[ "${NEW_SEED}" =~ ^[0-9]+$ ]] ||
       [ "${NEW_SEED}" -gt 2147483647 ]; then
        usage_error "+seed must be an integer from 0 to 2147483647."
    fi
fi

if [ -n "${NEW_SIZE}" ]; then
    if ! [[ "${NEW_SIZE}" =~ ^[0-9]+$ ]] ||
       [ "${NEW_SIZE}" -lt 1000 ] ||
       [ "${NEW_SIZE}" -gt 6000 ]; then
        usage_error "+size must be an integer from 1000 to 6000."
    fi
fi

# Prepare master.config when map settings are being changed
if [ "${NEW_MAP}" -eq 1 ] || [ -n "${NEW_SEED}" ] || [ -n "${NEW_SIZE}" ]; then
    if [ ! -f "${MASTER_CONFIG}" ]; then
        if ! cp -a "${RUST_ENV}" "${MASTER_CONFIG}"; then
            log "ERROR! - Unable to create Rust server master.config!" >&2
            exit 1
        fi
    fi

    if [ "${NEW_MAP}" -eq 1 ]; then
        NEW_SEED=$(( $(od -An -N4 -tu4 /dev/urandom) % 2147483648 ))
    fi

    if [ -n "${NEW_SEED}" ]; then
        if ! update_master_setting "RUST_SERVER_SEED" "${NEW_SEED}"; then
            log "ERROR! - Unable to update Rust server seed in master.config!" >&2
            exit 1
        fi
        log "Rust server master.config seed set to: ${NEW_SEED}"
    fi

    if [ -n "${NEW_SIZE}" ]; then
        if ! update_master_setting "RUST_SERVER_WORLDSIZE" "${NEW_SIZE}"; then
            log "ERROR! - Unable to update Rust server world size in master.config!" >&2
            exit 1
        fi
        log "Rust server master.config world size set to: ${NEW_SIZE}"
    fi

    if ! rust_config_ownership; then
        exit 1
    fi

    log "Rust server master.config updated successfully!"
    log "######"
    exit 0
fi

# Verify Rust server master config file exists
if [ ! -f "${RUST_MASTER_CONFIG}" ]; then
    if ! cp -a "${RUST_SERVER_ENV}" "${RUST_MASTER_CONFIG}"; then
        log "ERROR! - Unable to create Rust server master.config!" >&2
        exit 1
    fi
fi

# Set ownership of Rust server config files
if ! rust_config_ownership; then
    exit 1
fi

# Verify Rust server service unit exists and is inactive
if [ ! -f "${RUST_SERVICE}" ]; then
    log "ERROR! - Rust server [systemd] service unit not found: ${RUST_SERVICE}" >&2
    exit 1
elif /usr/bin/systemctl is-active --quiet "$(basename "${RUST_SERVICE}")"; then
    log "ERROR! - Rust server service is currently active! Aborting..." >&2
    exit 1
fi

# Compare Rust server master.config with dot-env config
if cmp -s "${MASTER_CONFIG}" "${RUST_ENV}"; then
    log "Rust server service config unchanged..."
    exit 0
fi

# Ensure Rust server world backup directory exists
if ! mkdir -p -m 770 "${WORLD_BACKUP_DIR}"; then
    log "ERROR! - Unable to create Rust server world backup directory!" >&2
    exit 1
fi

# Backup current Rust server dot-env config
if ! cp -a "${RUST_ENV}" "${WORLD_BACKUP}"; then
    log "ERROR! - Unable to backup current Rust server config!" >&2
    exit 1
fi
# Log backup
log "Backed-up Rust server config to: $(basename "${WORLD_BACKUP}")"

# Apply Rust server master config
if ! cp -- "${MASTER_CONFIG}" "${RUST_ENV}"; then
    log "ERROR! - Unable to update Rust server dot-env config!" >&2
    exit 1
fi

# Set ownership of Rust server config files
if ! rust_config_ownership; then
    exit 1
fi

# Confirm Rust server dot-env has been updated
log "IMPORTANT! Rust server master.config new settings written to dot-env file..."

# Done
log "Process completed successfully!"
log "######"
exit 0


#EOF<*>
