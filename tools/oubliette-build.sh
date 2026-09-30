#!/usr/bin/env bash
# Build oubliette hardened stages via catalyst.
#
# Usage: oubliette-build.sh [OPTIONS]
#
# Options:
#   --mailto EMAIL    send failure alert and new-file summary to EMAIL
#   --logfile FILE    append all output to FILE (required for failure email log tails)
#   --full            ignore any failed run and start a full rebuild
#   --max-age HOURS   resume a failed run only if younger than HOURS (default 72)
#   -h, --help        show this help
#
# A failed run is resumed on the next invocation: specs whose output already
# exists are skipped and the failed spec continues via catalyst autoresume.

set -euo pipefail
shopt -s nullglob

TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # read by the sourced catalyst-auto conf
REPO_DIR="$(dirname -- "${TOOLS_DIR}")"
AUTO_CONF="${TOOLS_DIR}/catalyst-auto-amd64.conf"
CATALYST_CONF=/etc/catalyst/catalyst.conf
STOREDIR=/var/tmp/catalyst

# catalyst-auto keeps its expanded specs and logs under TMP_PATH; keep them
# off /tmp so a failed run survives a reboot and can be resumed.
export TMP_PATH="${STOREDIR}/auto"

MAILTO=""
LOGFILE=""
FORCE_FULL=0
MAX_AGE_HOURS=72
BEFORE_FILES=""

usage() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

log() { printf '[oubliette releng] %s\n' "$*"; }

send_email() {
    local subject="$1" body="$2"
    [[ -n "$MAILTO" ]] || return 0
    command -v sendmail >/dev/null 2>&1 || { log "sendmail not found, skipping email"; return 0; }
    printf 'To: %s\nSubject: [oubliette-releng] %s\n\n%s\n' \
        "$MAILTO" "$subject" "$body" | sendmail -t 2>/dev/null || true
}

find_stage_files() {
    find "${STOREDIR}/builds" -type f \
        \( -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.tar.gz" \
           -o -name "*.iso" -o -name "*.sfs" \) \
        ! -name "*-latest.*" 2>/dev/null | sort || true
}

on_exit() {
    local rc=$1
    [[ -n "$MAILTO" ]] || return 0
    if [[ $rc -ne 0 ]]; then
        local body
        body="Build failed with exit code ${rc} at $(date)."
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
            --full)     FORCE_FULL=1 ;;
            --max-age)  shift; MAX_AGE_HOURS="${1:-}"
                        [[ "$MAX_AGE_HOURS" =~ ^[0-9]+$ ]] || { log "--max-age needs a number of hours"; exit 1; } ;;
            -h|--help)  usage ;;
            *)          log "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done
}

# Print "<spec> required|optional" in catalyst-auto build order.
list_specs() {
    (
        set +u
        # shellcheck disable=SC2034 # read by the sourced catalyst-auto conf
        BUILD_SRCDIR_BASE="${STOREDIR}"
        # shellcheck source=catalyst-auto-amd64.conf
        source "${AUTO_CONF}"
        for set_name in "" ${SETS}; do
            if [[ -z "${set_name}" ]]; then
                specs_var="SPECS" optional_var="OPTIONAL_SPECS"
            else
                specs_var="SET_${set_name}_SPECS" optional_var="SET_${set_name}_OPTIONAL_SPECS"
            fi
            for s in ${!specs_var}; do echo "${s} required"; done
            for s in ${!optional_var}; do echo "${s} optional"; done
        done
    )
}

spec_value() {
    grep -Po "^${2}:\s*\K\S+" "$1" | head -n 1
}

# Output path (without extension) catalyst writes for an expanded spec.
spec_output() {
    local spec=$1
    printf '%s/builds/%s/%s-%s-%s' "${STOREDIR}" \
        "$(spec_value "$spec" rel_type)" "$(spec_value "$spec" target)" \
        "$(spec_value "$spec" subarch)" "$(spec_value "$spec" version_stamp)"
}

# Catalyst autoresume skips setup_confdir, so the chroot keeps the
# /etc/portage it was unpacked with. Drop that resume point to pick up
# portage_confdir changes made since the failed run.
refresh_confdir() {
    local spec=$1
    rm -f "$(printf '%s/tmp/%s/.autoresume-%s-%s-%s/setup_confdir' "${STOREDIR}" \
        "$(spec_value "$spec" rel_type)" "$(spec_value "$spec" target)" \
        "$(spec_value "$spec" subarch)" "$(spec_value "$spec" version_stamp)")"
}

spec_built() {
    local out
    out=$(spec_output "$1")
    compgen -G "${out}.tar*" >/dev/null
}

latest_run_dir() {
    local dirs=("${TMP_PATH}"/catalyst-auto.*/)
    [[ ${#dirs[@]} -gt 0 ]] || return 0
    ls -dt "${dirs[@]}" | head -n 1 | sed 's:/$::'
}

run_age_hours() {
    echo $(( ($(date +%s) - $(stat -c %Y "$1/specs")) / 3600 ))
}

# Drop catalyst chroots/autoresume state for a run, then the run dir itself.
purge_run() {
    local run_dir=$1 spec
    log "Purging catalyst tmp for ${run_dir##*/}"
    while read -r spec; do
        catalyst --purgetmponly -c "${CATALYST_CONF}" -f "${spec}" >/dev/null 2>&1 || true
    done < <(find "${run_dir}/specs" -name '*.spec')
    rm -rf "${run_dir}"
}

# Point <name>-latest at a freshly built stage3, as update_symlinks does.
link_latest() {
    local run_dir=$1 spec=$2 ts f
    [[ "$(spec_value "$spec" target)" == stage3 ]] || return 0
    ts=${run_dir##*/catalyst-auto.}
    ts=${ts%.*}
    for f in "$(spec_output "$spec")".tar*; do
        ln -sf "${f##*/}" "${f/${ts}/latest}"
    done
}

# Build every spec of a run whose output is missing. With --check, only
# report what is missing. Returns non-zero if anything is still unbuilt.
build_pending() {
    local run_dir=$1 check=${2:-} spec kind specfile speclog rc=0 skip_optional=0
    while read -r spec kind; do
        specfile="${run_dir}/specs/${spec}"
        if spec_built "${specfile}"; then
            [[ -n "$check" ]] || log "${spec}: already built, skipping"
            continue
        fi
        if [[ -n "$check" ]]; then
            log "${spec}: missing output"
            rc=1
            continue
        fi
        if [[ $skip_optional -eq 1 ]]; then
            log "${spec}: skipped after earlier optional failure"
            continue
        fi

        speclog="${run_dir}/log/$(echo "${spec}" | sed -e 's:/:_:g' -e 's:\.spec$::').log"
        log "${spec}: building (resume), log ${speclog}"
        refresh_confdir "${specfile}"
        if catalyst -c "${CATALYST_CONF}" -f "${specfile}" >>"${speclog}" 2>&1; then
            link_latest "${run_dir}" "${specfile}"
            continue
        fi

        log "${spec}: FAILED, last lines of ${speclog}:"
        tail -n 50 "${speclog}" || true
        rc=1
        [[ "$kind" == required ]] && return 1
        skip_optional=1
    done < <(list_specs)
    return $rc
}

reindex_binpkgs() {
    local profile_dir pkgdir
    for profile_dir in "${STOREDIR}/packages"/*; do
        [[ -d ${profile_dir} ]] || continue
        for pkgdir in "${profile_dir}"/*; do
            [[ -d ${pkgdir} ]] || continue
            log "indexing ${profile_dir##*/} ${pkgdir##*/} packages"
            PKGDIR="${pkgdir}" emaint binhost -f
        done
    done
}

full_build() {
    local run_dir specs

    for run_dir in "${TMP_PATH}"/catalyst-auto.*/; do
        purge_run "${run_dir%/}"
    done

    log "Fetch latest Gentoo stage3 for seeding"
    "${TOOLS_DIR}/download-stage3-seed.sh"

    log "Purge previously built live packages"
    find "${STOREDIR}/packages/" -name "*-9999*" -type f -print -delete 2>/dev/null || true

    reindex_binpkgs

    # Keep catalyst tmp/autoresume state of every spec, so a failure can be
    # resumed; purge_run cleans up once the whole run has succeeded.
    specs=$(list_specs | cut -d' ' -f1 | tr '\n' ' ')
    mkdir -p "${TMP_PATH}"

    log "Running catalyst-auto amd64"
    CLST_AUTO_NOCLEAN="${specs}" \
        "${TOOLS_DIR}/catalyst-auto" -X -v -k -c "${AUTO_CONF}" || true

    # catalyst-auto exits 0 even when a spec fails, so judge by outputs.
    run_dir=$(latest_run_dir)
    [[ -n "${run_dir}" ]] || { log "catalyst-auto left no run dir"; return 1; }
    if ! build_pending "${run_dir}" --check; then
        log "Build incomplete; rerun within ${MAX_AGE_HOURS}h to resume ${run_dir##*/}"
        return 1
    fi
    purge_run "${run_dir}"
}

resume_build() {
    local run_dir=$1
    log "Resuming ${run_dir##*/} ($(run_age_hours "${run_dir}")h old)"

    reindex_binpkgs

    if ! build_pending "${run_dir}"; then
        log "Resume failed; rerun to continue ${run_dir##*/}, or pass --full"
        return 1
    fi
    purge_run "${run_dir}"
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

    local run_dir
    run_dir=$(latest_run_dir)

    if [[ -z "${run_dir}" ]]; then
        full_build
    elif [[ $FORCE_FULL -eq 1 ]]; then
        log "--full given, discarding ${run_dir##*/}"
        full_build
    elif [[ $(run_age_hours "${run_dir}") -ge $MAX_AGE_HOURS ]]; then
        log "${run_dir##*/} is older than ${MAX_AGE_HOURS}h, starting full rebuild"
        full_build
    else
        resume_build "${run_dir}"
    fi
}

main "$@"
