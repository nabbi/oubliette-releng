#!/usr/bin/env bash
# Build oubliette hardened stages via catalyst.
#
# Usage: oubliette-build.sh [OPTIONS]
#
# Options:
#   --mailto EMAIL    send failure alert and new-file summary to EMAIL
#   --logfile FILE    append all output to FILE (required for failure email log tails)
#   -h, --help        show this help

set -euo pipefail
shopt -s nullglob

TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MAILTO=""
LOGFILE=""
BEFORE_FILES=""

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

log() { printf '[oubliette build] %s\n' "$*"; }

send_email() {
    local subject="$1" body="$2"
    [[ -n "$MAILTO" ]] || return 0
    command -v sendmail >/dev/null 2>&1 || { log "sendmail not found, skipping email"; return 0; }
    printf 'To: %s\nSubject: [oubliette-build] %s\n\n%s\n' \
        "$MAILTO" "$subject" "$body" | sendmail -t 2>/dev/null || true
}

find_stage_files() {
    find /var/tmp/catalyst/builds -type f \
        \( -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.tar.gz" \
           -o -name "*.iso" -o -name "*.sfs" \) \
        ! -name "*-latest.*" 2>/dev/null | sort || true
}

on_exit() {
    local rc=$1
    [[ -n "$MAILTO" ]] || return 0
    if [[ $rc -ne 0 ]]; then
        local body="Build failed with exit code ${rc} at $(date)."
        if [[ -n "$LOGFILE" && -f "$LOGFILE" ]]; then
            body+=$'\n\nLast 100 lines of '"${LOGFILE}"':'
            body+=$'\n'"$(tail -n 100 "$LOGFILE" 2>/dev/null || true)"
        fi
        send_email "BUILD FAILED" "$body"
    else
        local after_files new_files body
        after_files=$(find_stage_files)
        new_files=$(comm -13 \
            <(echo "${BEFORE_FILES:-}" | grep -v '^$' | sort) \
            <(echo "${after_files:-}" | grep -v '^$' | sort) 2>/dev/null || true)
        body="Build completed successfully at $(date)."
        if [[ -n "$new_files" ]]; then
            body+=$'\n\nNew files built:\n'"$new_files"
        else
            body+=$'\n\nNo new artifact files detected (build may have been up to date).'
        fi
        send_email "build success" "$body"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mailto)   shift; MAILTO="${1:-}" ;;
            --logfile)  shift; LOGFILE="${1:-}" ;;
            -h|--help)  usage ;;
            *)          log "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    [[ $(id -u) -eq 0 ]] || { log "Error: must be run as root"; exit 1; }

    if [[ -n "$LOGFILE" ]]; then
        mkdir -p "$(dirname "$LOGFILE")"
        exec >> "$LOGFILE" 2>&1
    fi

    log "Build started at $(date)"

    BEFORE_FILES=$(find_stage_files)
    trap 'on_exit $?' EXIT

    log "Fetch latest Gentoo stage3 for seeding"
    "${TOOLS_DIR}/download-stage3-seed.sh"

    log "Purge previously built live packages"
    find /var/tmp/catalyst/packages/ -name "*-9999*" -type f -print -delete 2>/dev/null || true

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
}

main "$@"
