#!/usr/bin/env bash
# Follow the logs of a running (or failed) oubliette-build.sh run.
#
# Usage: oubliette-watch.sh [MODE]
#
# Modes:
#   (default)         progress notes: spec started, catalyst action steps,
#                     emerge (n of m) package lines, errors and warnings
#   -r, --raw         tail the full log of the spec being built
#   -p, --pkg         tail build.log of the package being compiled in the chroot
#   -s, --status      print a one-shot summary of every spec and exit
#   -h, --help        show this help
#
# The followed log switches automatically when catalyst moves to the next
# spec (or package, with --pkg). Waits for a run to start if none exists.

set -euo pipefail
shopt -s nullglob

TOOLS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # read by the sourced catalyst-auto conf
REPO_DIR="$(dirname -- "${TOOLS_DIR}")"
AUTO_CONF="${TOOLS_DIR}/catalyst-auto-amd64.conf"
STOREDIR=${STOREDIR:-/var/tmp/catalyst}
TMP_PATH="${STOREDIR}/auto"
POLL=5

if [[ -t 1 ]]; then
    C_OFF=$'\e[0m' C_DIM=$'\e[2m' C_BOLD=$'\e[1m'
    C_RED=$'\e[31m' C_YEL=$'\e[33m' C_GRN=$'\e[32m' C_CYN=$'\e[36m'
else
    C_OFF="" C_DIM="" C_BOLD="" C_RED="" C_YEL="" C_GRN="" C_CYN=""
fi
# progress_filter also runs in a setsid'd bash
export C_OFF C_DIM C_RED C_YEL C_GRN C_CYN

TAIL_PID=""

usage() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

note() { printf '%s%s%s %s\n' "${C_DIM}" "$(date +%T)" "${C_OFF}" "$*"; }

stop_tail() {
    if [[ -n "${TAIL_PID}" ]]; then
        kill -- "-${TAIL_PID}" 2>/dev/null || kill "${TAIL_PID}" 2>/dev/null || true
        wait "${TAIL_PID}" 2>/dev/null || true
        TAIL_PID=""
    fi
}

trap 'stop_tail; exit 0' INT TERM
trap 'stop_tail' EXIT

latest_run_dir() {
    local dirs=("${TMP_PATH}"/catalyst-auto.*/)
    [[ ${#dirs[@]} -gt 0 ]] || return 0
    ls -dt "${dirs[@]}" | head -n 1 | sed 's:/$::'
}

newest_file() {
    [[ $# -gt 0 ]] || return 0
    ls -t "$@" 2>/dev/null | head -n 1
}

# Spec logs, excluding the snapshot/pre/post_build and purge logs.
spec_logs() {
    local f
    for f in "$1"/log/*.log; do
        case "${f##*/}" in
            snapshot.log|pre_build.log|post_build.log|*_purge.log) ;;
            *) echo "$f" ;;
        esac
    done
}

current_spec_log() {
    local logs
    mapfile -t logs < <(spec_logs "$1")
    newest_file "${logs[@]}"
}

current_pkg_log() {
    newest_file "${STOREDIR}"/tmp/*/*/var/tmp/portage/*/*/temp/build.log
}

# Print "<spec>" in catalyst-auto build order, as oubliette-build.sh does.
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
            for s in ${!specs_var} ${!optional_var}; do echo "${s}"; done
        done
    )
}

spec_value() {
    grep -Po "^${2}:\s*\K\S+" "$1" | head -n 1
}

spec_built() {
    compgen -G "$(printf '%s/builds/%s/%s-%s-%s' "${STOREDIR}" \
        "$(spec_value "$1" rel_type)" "$(spec_value "$1" target)" \
        "$(spec_value "$1" subarch)" "$(spec_value "$1" version_stamp)").tar*" >/dev/null
}

spec_log_path() {
    echo "$1/log/$(echo "$2" | sed -e 's:/:_:g' -e 's:\.spec$::').log"
}

# Condense a spec log into progress notes. Lines already in the log when
# we attach are replayed without a timestamp, new ones get the wall clock.
progress_filter() {
    gawk -v live="$1" -v red="${C_RED}" -v yel="${C_YEL}" -v grn="${C_GRN}" \
         -v cyn="${C_CYN}" -v dim="${C_DIM}" -v off="${C_OFF}" '
        function out(s) {
            if (live) printf "%s%s%s %s\n", dim, strftime("%T"), off, s
            else      printf "%s  ....  %s %s\n", dim, off, s
            fflush()
        }
        { sub(/\r$/, ""); gsub(/\x1b\[[0-9;]*[mK]/, "") }
        /--- Running action sequence: / {
            sub(/.*Running action sequence: /, ""); out(cyn "step " $0 off); next
        }
        /Resume point detected/ { sub(/.*NOTICE *: /, ""); out(dim "  " $0 off); next }
        /^>>> Emerging/ {
            if (match($0, /\(([0-9]+) of ([0-9]+)\) ([^ ]+)/, m)) {
                kind = ($0 ~ /binary/) ? "bin" : "src"
                out(sprintf("  [%s/%s] %s %s", m[1], m[2], kind, m[3]))
            }
            next
        }
        /^emerge / {
            s = $0; if (length(s) > 150) s = substr(s, 1, 147) "..."
            out(dim "  " s off); next
        }
        / \* ERROR: |^>>> Failed to |: ERROR *: |^!!! |^Traceback / { out(red $0 off); next }
        /: WARNING *: / { sub(/.*WARNING *: /, ""); out(yel "  warn: " $0 off); next }
        /[0-9:.]+elapsed / {
            if (match($0, /([0-9:.]+)elapsed/, m)) out(grn "done in " m[1] off); next
        }
        /^real[ \t]/ { out(grn "done in " $2 off); next }
    '
}

export -f progress_filter

# Follow the file printed by $picker, switching when it changes.
# $1: picker function, $2: filter (progress|raw), $3: label
follow() {
    local picker=$1 mode=$2 label=$3 run_dir="" cur="" new size
    while true; do
        new=$(latest_run_dir)
        if [[ "${new}" != "${run_dir}" ]]; then
            if [[ -n "${run_dir}" && ! -d "${run_dir}" ]]; then
                stop_tail; cur=""
                note "${C_GRN}${C_BOLD}run ${run_dir##*/} finished and was cleaned up${C_OFF}"
            fi
            run_dir=${new}
            if [[ -n "${run_dir}" ]]; then
                note "${C_BOLD}following run ${run_dir##*/}${C_OFF}"
            else
                note "waiting for a run in ${TMP_PATH}"
            fi
        fi

        if [[ -n "${run_dir}" ]]; then
            if [[ ! -r "${run_dir}/log" ]]; then
                echo "Cannot read ${run_dir}/log; rerun as root" >&2
                exit 1
            fi
            new=$("${picker}" "${run_dir}")
            if [[ -n "${new}" && "${new}" != "${cur}" ]]; then
                stop_tail
                cur=${new}
                note "${C_BOLD}${label} $(describe "${cur}" "${run_dir}")${C_OFF}"
                note "${C_DIM}${cur}${C_OFF}"
                # setsid so stop_tail can kill the whole tail|filter group
                if [[ "${mode}" == progress ]]; then
                    size=$(stat -c %s "${cur}")
                    head -c "${size}" "${cur}" | progress_filter 0
                    # shellcheck disable=SC2016 # expanded by the inner bash
                    setsid bash -c 'tail -c +"$(($2 + 1))" -F "$1" 2>/dev/null | progress_filter 1' \
                        _ "${cur}" "${size}" &
                else
                    setsid tail -n 40 -F "${cur}" 2>/dev/null &
                fi
                TAIL_PID=$!
            fi
        fi
        sleep "${POLL}"
    done
}

describe() {
    local f=$1 run_dir=$2 n total name
    case "$f" in
        */temp/build.log)
            f=${f%/temp/build.log}
            echo "${f#*/var/tmp/portage/}"
            ;;
        *)
            name=${f##*/}; name=${name%.log}
            total=$(find "${run_dir}/specs" -name '*.spec' | wc -l)
            n=$(spec_logs "${run_dir}" | wc -l)
            echo "spec [${n}/${total}] ${name}"
            ;;
    esac
}

status() {
    local run_dir spec specfile speclog active state last step age
    run_dir=$(latest_run_dir)
    if [[ -z "${run_dir}" ]]; then
        echo "No run in ${TMP_PATH}"
        return 0
    fi
    [[ -r "${run_dir}/log" ]] || { echo "Cannot read ${run_dir}/log; rerun as root" >&2; exit 1; }

    age=$(( ($(date +%s) - $(stat -c %Y "${run_dir}/specs")) / 60 ))
    echo "${C_BOLD}run ${run_dir##*/}${C_OFF} (started ${age} min ago)"
    active=$(current_spec_log "${run_dir}")
    pgrep -x catalyst >/dev/null 2>&1 || pgrep -f 'bin/catalyst ' >/dev/null 2>&1 || active=""

    while read -r spec; do
        specfile="${run_dir}/specs/${spec}"
        speclog=$(spec_log_path "${run_dir}" "${spec}")
        [[ -f "${specfile}" ]] || continue
        if spec_built "${specfile}"; then
            state="${C_GRN}built${C_OFF}   "
        elif [[ "${speclog}" == "${active}" ]]; then
            state="${C_CYN}building${C_OFF}"
        elif [[ -f "${speclog}" ]]; then
            state="${C_RED}failed${C_OFF}  "
        else
            state="${C_DIM}pending${C_OFF} "
        fi
        printf '  %s %s\n' "${state}" "${spec}"

        if [[ "${speclog}" == "${active}" ]] || { [[ -f "${speclog}" ]] && ! spec_built "${specfile}"; }; then
            step=$(grep -a 'Running action sequence:' "${speclog}" | tail -n 1 | sed 's/.*sequence: //')
            last=$(grep -a '^>>> Emerging' "${speclog}" | tail -n 1 | grep -Po '\(\d+ of \d+\) \S+' || true)
            [[ -n "${step}" ]] && printf '             step  %s\n' "${step}"
            [[ -n "${last}" ]] && printf '             emerge %s\n' "${last}"
            if [[ "${speclog}" != "${active}" ]]; then
                grep -aE ' \* ERROR: |^>>> Failed to |: ERROR *: ' "${speclog}" | tail -n 3 \
                    | sed "s/^/             ${C_RED}/; s/\$/${C_OFF}/"
            fi
            printf '             %s%s%s\n' "${C_DIM}" "${speclog}" "${C_OFF}"
        fi
    done < <(list_specs)
}

main() {
    local mode=progress
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--raw)    mode=raw ;;
            -p|--pkg)    mode=pkg ;;
            -s|--status) mode=status ;;
            -h|--help)   usage ;;
            *)           echo "Unknown option: $1" >&2; exit 1 ;;
        esac
        shift
    done

    case "${mode}" in
        progress) follow current_spec_log progress "now on" ;;
        raw)      follow current_spec_log raw "now on" ;;
        pkg)      follow current_pkg_log raw "compiling" ;;
        status)   status ;;
    esac
}

main "$@"
