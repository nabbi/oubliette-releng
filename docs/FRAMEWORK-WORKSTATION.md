# Framework Workstation Stage4

Custom hardened stage4 for the Framework Workstation (Framework Desktop, AMD Ryzen AI Max+ PRO
495, up to 192 GB LPDDR5X-8533 soldered, Radeon 8060S iGPU, XDNA NPU), run headless as an LLM
server and administered over ssh.

Vendor guidance: kernel **7.3 minimum**, 7.3+ recommended
(<https://frame.work/desktop?tab=linux>, "AMD Ryzen AI Max PRO 400 Series"). The 300 series
needs 6.11.

## Spec

`releases/specs/amd64/hardened/stage4-openrc-23-framework-workstation.spec`, in
`SET_hardened_openrc_23_splitusr_OPTIONAL_SPECS` in `tools/catalyst-auto-amd64.conf` after the
Framework 13 Pro spec. Same chain as that one: 23.0 split-usr hardened, `rel_type:
23.0-hardened-splitusr`. Build artifacts are named
`stage4-amd64-hardened-oubliette-framework-workstation-splitusr-<timestamp>`.

Differences from the 13 Pro stage4 (`FRAMEWORK.md`):

- no X.org, window manager, audio, Bluetooth stack, fingerprint, zram swap, thermald, power-profiles-daemon,
  framework_tool or Intel packages
- `VIDEO_CARDS: -* amdgpu radeonsi`, `media-libs/mesa vulkan` (radv)
- `sci-ml/ollama` with `vulkan` (and `sci-ml/ggml vulkan`), `dev-util/vulkan-tools`,
  `sys-process/nvtop`, htop, lm-sensors. ollama's init script is installed; the image does not
  enable it
- AMD microcode comes in linux-firmware (`amd-ucode`); `package.use/linux-firmware` sets
  `initramfs`, so dracut's `early_microcode=yes` embeds it in the initramfs
- nftables allows ssh only; the ollama port is not opened, use `ssh -L 11434:localhost:11434`

## linux-firmware

Savedconfig `releases/portage/framework-workstation/savedconfig/sys-kernel/linux-firmware`,
generated for 20261019 (2026-11-21) by `gen-fw-savedconfig.sh` next to it (96 files):

| Subsystem | Firmware | Hardware |
|-----------|----------|----------|
| amdgpu | `gc_11_5_*`, `psp_14_0_*`, `smu_14_0_*`, `sdma_6_1_*`, `vcn_4_0_5`, `dcn_3_5*`, `vpe_6_1_*`, `isp_4_1_1`, `umsch_mm_4_0_0` | Strix Halo / Point / Krackan family; the `gc_11_5` set is kept whole so a refreshed die still binds |
| XDNA NPU | `amdnpu/*` | `amdxdna` |
| Microcode | `amd-ucode/*` | AMD CPU microcode |
| RTL8126 | `rtl_nic/rtl8126a-*` | 5 GbE (also `rtl815[36]` for USB dongles) |
| MT7925 | `mediatek/mt7925/*` | "AMD RZ717" Wi-Fi 7 and Bluetooth |

Framework's pages name the Wi-Fi module "RZ717" without the chip; it is the MediaTek MT7925, and
this is to be confirmed on the hardware (`lspci -nn`). Regenerate after a linux-firmware bump
with the recipe in `FRAMEWORK.md`, using `FW_ROOT` of an unpruned install. Remove the cached
linux-firmware binpkgs from the catalyst storedir first (`tools/oubliette-build.sh` does for full
builds).

## Kernel config

No kernel in the image; the host builds `sys-kernel/gentoo-kernel` (the fsscript adds it to
`@world`) with `/etc/kernel/config.d/framework-workstation.config`: `DRM_AMDGPU`, KFD
(`HSA_AMD`, `HSA_AMD_SVM`, `HMM_MIRROR`, `DEVICE_PRIVATE`), `DRM_ACCEL_AMDXDNA`, `R8169`,
`MT7925E`/`MT7925U` + `BT_MTK`, `AMD_IOMMU`, `X86_AMD_PSTATE`, `TCG_CRB`, `USB4`, and a GOP console
(`SIMPLEDRM`) until amdgpu loads. All 30 symbols survive on gentoo-kernel-7.3.5_p1 (checked
2026-11-21, recipe in `releases/kconfig/amd64/README.md`). `package.accept_keywords` keywords
`=sys-kernel/gentoo-kernel-7.3*`.

The fragment is untested on the hardware: the build was checked against the dist config only.

## GPU memory for LLMs

The iGPU uses system RAM. Large models need the GTT limit raised on the kernel command line
(`ttm.pages_limit=<pages>` in 4 KiB pages, with `amdgpu.gttsize=<MiB>`); the BIOS UMA frame
buffer can stay small. The values depend on the RAM fitted and are set per host.

Reports on the Framework wiki mention GPU hangs under heavy inference on some kernels, with
`amdgpu.cwsr_enable=0` as a workaround; not applied here.

## ROCm

Not in the image: a HIP build of ggml/ollama compiles for hours. To try it on the host, enable
`sci-ml/ggml rocm` and set `AMDGPU_TARGETS: gfx1151` (the Gentoo `rocm` eclass knows gfx1151). Vulkan
runs on mesa alone.

## Admin ISO

The admincd boots the machine with kernel 7.3.5 (`releases/kconfig/amd64/amd64-7.3.5-admincd.config`):
GOP console, `R8169` for the 5 GbE port, `MT7925E`, `AMD_IOMMU`. amdgpu stays out of it, as its
firmware is pruned from the ISO.
