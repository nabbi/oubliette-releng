#!/usr/bin/env bash
# gen-fw-savedconfig.sh — Prune linux-firmware to Framework 13 Pro essentials
#
# Mirrors the approach of isos/savedconfig/sys-kernel/prune_firmwares.sh but
# inverts the inclusion set: exclude everything by default, keep only the
# Intel-family firmware the Framework 13 Pro (Panther Lake Xe3 iGPU, BE211
# Wi-Fi 7, Bluetooth, CS42L43 SOF audio via SoundWire) actually needs.
#
# File format (same as prune_firmwares.sh output):
#   uncommented line  = install this file
#   #-prefixed line   = do not install this file
#
# Usage:
#   Run on a machine with linux-firmware installed, or point at a savedconfig
#   file from the upstream linux-firmware tarball:
#
#   bash gen-fw-savedconfig.sh \
#       /etc/portage/savedconfig/sys-kernel/linux-firmware-20250808 \
#       > linux-firmware
#
#   git add linux-firmware && git commit -sS
#
# The input must be the VANILLA savedconfig (all firmware entries uncommented).
# Obtain one from an installed package:
#   find /lib/firmware -type f | sed 's|/lib/firmware/||' | sort

set -euo pipefail

[[ $# -eq 1 ]] || { echo "Usage: $0 <vanilla-savedconfig>" >&2; exit 1; }
INPUT="$1"
[[ -f "${INPUT}" ]] || { echo "File not found: ${INPUT}" >&2; exit 1; }

{
    echo "# $(git config user.name) <$(git config user.email)> ($(date +%Y-%m-%d))"
    echo "# Last updated for $(basename "${INPUT}")"
    echo "# Framework 13 Pro: Panther Lake Xe3 iGPU, BE211 WiFi, BT, SOF audio — all others excluded"
    echo "#"
    echo "# To regenerate after a linux-firmware update:"
    echo "#   bash gen-fw-savedconfig.sh <new-vanilla-savedconfig> > linux-firmware"

    # Normalize input: strip any leading # from firmware paths (not from comment
    # lines that start with "# ") so we start from a clean uncommented baseline.
    grep -v '^#' "${INPUT}" | grep -v '^$' | sort -u | while IFS= read -r line; do

        # ── Keep (uncommented = install) ──────────────────────────────────────

        # Intel Xe GPU — Panther Lake (ptl_*) GuC/HuC/GSC firmware. DRM_I915 is
        # not enabled for this hardware, so plain i915/ blobs are not needed.
        [[ "${line}" =~ ^xe/ptl_ ]]           && echo "${line}" && continue

        # Intel WiFi — BE211 (Wi-Fi 7) uses iwlwifi-bz-* firmware
        [[ "${line}" =~ ^iwlwifi ]]           && echo "${line}" && continue

        # Intel Bluetooth (ibt-* covers all modern CNVi BT)
        [[ "${line}" =~ ^intel/ibt ]]         && echo "${line}" && continue

        # Intel SOF audio — .ri blobs and topology (.tplg) for CS42L43/SoundWire
        [[ "${line}" =~ ^intel/sof ]]         && echo "${line}" && continue

        # Intel DSP firmware (used by some SOF/ME subsystems on Xe platforms)
        [[ "${line}" =~ ^intel/dsp_fw ]]      && echo "${line}" && continue

        # Wireless regulatory database — required by all WiFi drivers
        [[ "${line}" =~ ^regulatory ]]        && echo "${line}" && continue

        # ── Exclude everything else (comment out = do not install) ────────────
        echo "#${line}"
    done
}
