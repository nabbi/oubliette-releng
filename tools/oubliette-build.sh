#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# REPO_DIR="$(cd -- "${TOOLS_DIR}/.." && pwd)"

log() {
    printf '[oubliette build] %s\n' "$*"
}

log "Fetch latest Gentoo stage3 for seeding"
"${TOOLS_DIR}/download-stage3-seed.sh"


log "Purge previously built live packages"
find /var/tmp/catalyst/packages/ -name "*-9999*" -type f -print -delete

for profile_dir in "/var/tmp/catalyst/packages"/*; do
    [[ -d ${profile_dir} ]] || continue

    profile_name=${profile_dir##*/}

    for pkgdir in "${profile_dir}"/*; do
        [[ -d ${pkgdir} ]] || continue

        stage_name=${pkgdir##*/}

        log "indexing ${profile_name} ${stage_name} packages"
        PKGDIR="${pkgdir}" emaint binhost -f
    done
done


log "Running catalyst-auto amd64"
"${TOOLS_DIR}/catalyst-auto" -X -v -c "${TOOLS_DIR}/catalyst-auto-amd64.conf"

