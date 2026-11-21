#!/usr/bin/env bash
# gen-fw-savedconfig.sh: prune linux-firmware to the Framework Workstation
# (Ryzen AI Max+ PRO 495, "Gorgon Halo", Radeon 8060S iGPU), headless.
#
# Same format as framework/savedconfig/sys-kernel/gen-fw-savedconfig.sh:
#   uncommented line  = install this file
#   #-prefixed line   = do not install this file
#
# The input is a list of every firmware path of the version to prune, from an
# unpruned install:
#   find /lib/firmware ! -type d -printf '%P\n' | sort > /tmp/vanilla
#   bash gen-fw-savedconfig.sh /tmp/vanilla > linux-firmware
# Kept symlinks are resolved against FW_ROOT (default /lib/firmware), which
# must hold the same linux-firmware version unpruned; see
# tools/fw-savedconfig-links.sh.

set -euo pipefail

[[ $# -eq 1 ]] || { echo "Usage: $0 <vanilla-file-list>" >&2; exit 1; }
INPUT="$1"
[[ -f "${INPUT}" ]] || { echo "File not found: ${INPUT}" >&2; exit 1; }
LINKS="$(git rev-parse --show-toplevel)/tools/fw-savedconfig-links.sh"

{
    echo "# $(git config user.name) <$(git config user.email)> ($(date +%Y-%m-%d))"
    echo "# Last updated for $(basename "${INPUT}")"
    echo "# Framework Workstation: Strix Halo iGPU (gfx1151), XDNA NPU, RTL8126 5GbE,"
    echo "# RZ717 (MediaTek MT7925) Wi-Fi 7 and Bluetooth, AMD microcode; all others excluded"
    echo "#"
    echo "# To regenerate after a linux-firmware update:"
    echo "#   bash gen-fw-savedconfig.sh <vanilla-file-list> > linux-firmware"

    sed -e 's/^#\([^ ]\)/\1/' "${INPUT}" | grep -v '^#' | grep -v '^$' | sort -u | while IFS= read -r line; do

        # amdgpu: Strix Halo / Strix Point / Krackan (GC 11.5.x, PSP/SMU 14.0.x,
        # SDMA 6.1.x, VCN 4.0.5, DCN 3.5.x, VPE 6.1.x, ISP 4.1). The gc_11_5
        # family is kept whole so a refreshed die ("Gorgon Halo") still binds.
        [[ "${line}" =~ ^amdgpu/(gc_11_5_|psp_14_0_|smu_14_0_|sdma_6_1_|vcn_4_0_5|dcn_3_5|vpe_6_1_|isp_4_1|umsch_mm_4_0_) ]] \
            && echo "${line}" && continue

        # AMD XDNA NPU (amdxdna)
        [[ "${line}" =~ ^amdnpu/ ]]           && echo "${line}" && continue

        # Microcode (amd-ucode/ is what linux-firmware's initramfs USE and
        # dracut's early_microcode read)
        [[ "${line}" =~ ^amd-ucode/ ]]        && echo "${line}" && continue
        [[ "${line}" =~ ^amd/ ]]              && echo "${line}" && continue

        # RTL8126 5GbE (r8169)
        [[ "${line}" =~ ^rtl_nic/rtl8126 ]]   && echo "${line}" && continue
        # USB Ethernet dongles (r8152 PHY patches)
        [[ "${line}" =~ ^rtl_nic/rtl815[36] ]] && echo "${line}" && continue

        # RZ717 = MediaTek MT7925 Wi-Fi 7 and Bluetooth
        [[ "${line}" =~ ^mediatek/mt7925 ]]   && echo "${line}" && continue

        # Wireless regulatory database
        [[ "${line}" =~ ^regulatory ]]        && echo "${line}" && continue

        echo "#${line}"
    done
} | "${LINKS}"
