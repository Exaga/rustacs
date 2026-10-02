#!/bin/bash

# Rust Administration & Control System - RUSTACS
#
# Rust server mod framework installer
#
# This script installs either Carbon or Oxide on an existing Rust server.
# The selected framework is downloaded from its current Linux release and
# extracted directly into the Rust server installation directory.
#
# Carbon and Oxide must not be installed together. This script checks for an
# existing installation of the other framework and aborts if one is found.
#
# The Rust server service MUST be inactive before this script will continue.
#
### IMPORTANT NOTES:
#
# The dot-env (.rustserver.env) file is a prerequisite for this script to
# run. It needs to be present on the system with the correct permissions
# beforehand.
#
# curl is required for downloading Carbon or Oxide. unzip is also required
# when installing Oxide.
#
### USAGE:
#
# Copy this script into a user directory - e.g. /home/rust/bin/
# Make the script executable:
#
#   chmod 770 /home/rust/bin/rustservermod.sh
#
# Install Carbon:
#
#   /home/rust/bin/rustservermod.sh carbon
#
# Install Oxide:
#
#   /home/rust/bin/rustservermod.sh oxide
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
#
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
RUST_DIR="${RUST_INSTALL_WORKDIR}"
RUST_SERVICE="${RUST_SERVICE_PATH}"
LOG_DIR="${RUST_LOGDIR}"
LOG_FILE="${LOG_DIR}/${PRGNAM}.log"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${PRGNAM}.XXXXXX")"

CARBON_URL="https://github.com/CarbonCommunity/Carbon.Core/releases/download/production_build/Carbon.Linux.Release.tar.gz"
CARBON_ARCHIVE="${TMP_DIR}/Carbon.Linux.Release.tar.gz"
OXIDE_URL="https://umod.org/games/rust/download"
OXIDE_ARCHIVE="${TMP_DIR}/Oxide.Rust-linux.zip"

# Progress log function
log() {
    printf "%(%F %T)T : %s: %s\n" "-1" "${PRGNAM}" "${1}" 2>&1 | tee -a "${LOG_FILE}"
}

# Remove temporary download directory
cleanup() {
    rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT

# Verify command argument
case "${1:-}" in
    carbon|oxide)
        MOD_FRAMEWORK="${1}"
        ;;
    *)
        echo "Usage: ${PRGNAM}.sh carbon|oxide" >&2
        exit 1
        ;;
esac

# Verify Rust server installation directory exists
if [ ! -d "${RUST_DIR}" ]; then
    log "ERROR! - Rust server installation directory not found: ${RUST_DIR}" >&2
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

# Verify required tools
if ! command -v curl >/dev/null 2>&1; then
    log "ERROR! - curl not found!" >&2
    exit 1
fi

if [ "${MOD_FRAMEWORK}" = "oxide" ] && ! command -v unzip >/dev/null 2>&1; then
    log "ERROR! - unzip not found!" >&2
    exit 1
fi

# Refuse mixed Carbon and Oxide installations
if [ "${MOD_FRAMEWORK}" = "carbon" ] && [ -d "${RUST_DIR}/oxide" ]; then
    log "ERROR! - Existing Oxide installation detected!" >&2
    log "ERROR! - Carbon and Oxide cannot be installed together. Aborting..." >&2
    exit 1
fi

if [ "${MOD_FRAMEWORK}" = "oxide" ] && [ -d "${RUST_DIR}/carbon" ]; then
    log "ERROR! - Existing Carbon installation detected!" >&2
    log "ERROR! - Carbon and Oxide cannot be installed together. Aborting..." >&2
    exit 1
fi

case "${MOD_FRAMEWORK}" in
    carbon)
        log "Downloading current Carbon Linux production release..."

        if ! curl -fL --retry 3 --connect-timeout 10 \
            -o "${CARBON_ARCHIVE}" "${CARBON_URL}"; then
            log "ERROR! - Unable to download Carbon!" >&2
            exit 1
        fi

        if [ ! -s "${CARBON_ARCHIVE}" ]; then
            log "ERROR! - Carbon download is empty!" >&2
            exit 1
        fi

        log "Installing Carbon into ${RUST_DIR}..."

        if ! tar -xzf "${CARBON_ARCHIVE}" -C "${RUST_DIR}"; then
            log "ERROR! - Unable to extract Carbon archive!" >&2
            exit 1
        fi
        ;;

    oxide)
        log "Downloading current Oxide Linux release..."

        if ! curl -fL --retry 3 --connect-timeout 10 \
            -o "${OXIDE_ARCHIVE}" "${OXIDE_URL}"; then
            log "ERROR! - Unable to download Oxide!" >&2
            exit 1
        fi

        if [ ! -s "${OXIDE_ARCHIVE}" ]; then
            log "ERROR! - Oxide download is empty!" >&2
            exit 1
        fi

        log "Installing Oxide into ${RUST_DIR}..."

        if ! unzip -oq "${OXIDE_ARCHIVE}" -d "${RUST_DIR}"; then
            log "ERROR! - Unable to extract Oxide archive!" >&2
            exit 1
        fi
        ;;
esac

# Set Rust server installation ownership
if ! sudo -n /usr/bin/chown -R \
    "${RUST_USERNAME}:${RUST_USERGROUP}" "${RUST_DIR}"; then
    log "ERROR! - Unable to set Rust server installation ownership!" >&2
    exit 1
fi

# Done
log "$(tr '[:lower:]' '[:upper:]' <<< "${MOD_FRAMEWORK:0:1}")${MOD_FRAMEWORK:1} installation completed successfully!"
log "######"
exit 0


#EOF<*>
