#!/usr/bin/env bash
set -euo pipefail

TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${TOOLS_DIR}/.." && pwd)"

log() {
    printf '[oubliette build] %s\n' "$*"
}

log "[prep] repo = ${REPO_DIR}"
log "[prep] tools = ${TOOLS_DIR}"

log "Fetch latest Gentoo stage3 for seeding"
"${TOOLS_DIR}/download-stage3-seed.sh"

log "Purge previously built live packages"
find /var/tmp/catalyst/packages/ -name "*-9999*" -type f -print -delete

log "Running catalyst-auto amd64"
"${TOOLS_DIR}/catalyst-auto" -X -v -c "${TOOLS_DIR}/catalyst-auto-amd64.conf"

