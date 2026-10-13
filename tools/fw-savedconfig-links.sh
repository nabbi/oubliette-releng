#!/usr/bin/env bash
# fw-savedconfig-links.sh — make a linux-firmware savedconfig symlink-complete
#
# linux-firmware ships many names as symlinks (e.g. iwlwifi-*.ucode ->
# intel/iwlwifi/iwlwifi-*.ucode since the 2026 releases). copy-firmware.sh only
# installs the paths a savedconfig lists, and the ebuild then deletes dangling
# symlinks, so a kept link whose target is not listed silently disappears.
#
# Reads a savedconfig on stdin and writes it to stdout with every kept link's
# chain of targets kept as well. Links are resolved against an installed
# firmware tree (FW_ROOT, default /lib/firmware) that must contain them.
#
#   --respect-pruned  a target that is commented out (#path) stays pruned and
#                     the link pointing at it is commented out too, instead of
#                     the target being uncommented (denylist-style configs)
#
# File format: "# " lines are comments, "#path" is pruned, "path" is kept.

set -euo pipefail

FW_ROOT="${FW_ROOT:-/lib/firmware}"
RESPECT_PRUNED=0
[[ "${1:-}" == "--respect-pruned" ]] && RESPECT_PRUNED=1

[[ -d "${FW_ROOT}" ]] || { echo "FW_ROOT not found: ${FW_ROOT}" >&2; exit 1; }

mapfile -t LINES
declare -A KEPT=() PRUNED=() DROP=() ADD=()

for line in "${LINES[@]}"; do
    case "${line}" in
        ''|'# '*|'#') ;;
        '#'*) PRUNED["${line#\#}"]=1 ;;
        *) KEPT["${line}"]=1 ;;
    esac
done

# Follow one link hop at a time so intermediate links in a chain are kept too
for name in "${!KEPT[@]}"; do
    chain=()
    cur="${name}"
    while [[ -L "${FW_ROOT}/${cur}" ]]; do
        dest="$(readlink "${FW_ROOT}/${cur}")"
        [[ "${dest}" == /* ]] && { echo "absolute link skipped: ${cur} -> ${dest}" >&2; break; }
        cur="$(realpath -ms --relative-to="${FW_ROOT}" "${FW_ROOT}/$(dirname "${cur}")/${dest}")"
        chain+=("${cur}")
    done
    [[ ${#chain[@]} -eq 0 ]] && continue

    if (( RESPECT_PRUNED )); then
        for t in "${chain[@]}"; do
            [[ -n "${PRUNED[${t}]:-}" ]] && { DROP["${name}"]=1; break; }
        done
        [[ -n "${DROP[${name}]:-}" ]] && continue
    fi
    for t in "${chain[@]}"; do
        [[ -n "${KEPT[${t}]:-}" ]] || ADD["${t}"]=1
    done
done

[[ ${#DROP[@]} -gt 0 ]] && echo "commented out ${#DROP[@]} link(s) into pruned targets" >&2
[[ ${#ADD[@]} -gt 0 ]] && echo "keeping ${#ADD[@]} link target(s)" >&2

for line in "${LINES[@]}"; do
    case "${line}" in
        ''|'# '*|'#') echo "${line}" ;;
        '#'*)
            if [[ -n "${ADD[${line#\#}]:-}" ]]; then
                echo "${line#\#}"
                unset 'ADD[${line#\#}]'
            else
                echo "${line}"
            fi
            ;;
        *) [[ -n "${DROP[${line}]:-}" ]] && echo "#${line}" || echo "${line}" ;;
    esac
done

# Targets missing from the input entirely (input older than FW_ROOT)
if [[ ${#ADD[@]} -gt 0 ]]; then
    echo
    echo "# Link targets not present in the input savedconfig"
    printf '%s\n' "${!ADD[@]}" | sort
fi
