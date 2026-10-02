# Framework 13 Pro Stage4

Custom hardened stage4 for the Framework 13 Pro (Intel Core Ultra Series 3 / Panther Lake,
e.g. Core Ultra X7 358H, with Arc B390 Xe3 graphics).

Built on top of the hardened OpenRC stage3 and supplemented by
[gentoo_initial_setup](https://github.com/nabbi/gentoo_initial_setup) tuned for this hardware.

## Spec

`releases/specs/amd64/hardened/stage4-openrc-23-framework.spec`

Added to `SET_hardened_openrc_23_OPTIONAL_SPECS` in `tools/catalyst-auto-amd64.conf` — build it
by passing the optional set flag to the build script.

## X.org / GPU

The Intel Xe3 iGPU (Arc B390, Panther Lake) is driven by the **modesetting** driver, which is
built into `x11-base/xorg-server`. No separate `xf86-video-*` package is needed or correct for
this hardware. Do not add `xf86-video-nouveau` or `xf86-video-intel`.

## linux-firmware

`sys-kernel/linux-firmware` is installed with `FEATURES=savedconfig` to prune firmware blobs
to only what the hardware requires:

| Subsystem | Firmware prefix | Hardware |
|-----------|----------------|----------|
| Intel Xe3 iGPU | `xe/ptl_*` | Panther Lake GuC/HuC/GSC firmware (Arc B390) |
| Intel Xe3 display | `i915/xe3lpd*_dmc.bin` | Display DMC (DC power states); `xe` loads it from `i915/` |
| Intel WiFi | `iwlwifi-sc-*`, `iwlwifi-bz-*` | BE211 (Wi-Fi 7); kernel 7.2 iwlmld needs core `-c102`+ |
| Intel Bluetooth | `intel/ibt-0040*`, `intel/ibt-0041*` | CNVi Bluetooth (paired with BE211) |
| Intel DSP | `intel/dsp_fw*` | Legacy SST/ME subsystem firmware |

SOF audio firmware/topology for the CS42L43 codec (SoundWire) is **not** part of
`linux-firmware` — it ships separately as `sys-firmware/sof-firmware` (see `stage4/packages`
in the spec). The regulatory database (`regulatory.db`) similarly comes from
`net-wireless/wireless-regdb`, not `linux-firmware`, on this profile.

To regenerate `releases/portage/framework/savedconfig/sys-kernel/linux-firmware` after a
`linux-firmware` version bump, run against a vanilla file list (e.g.
`find /lib/firmware -type f | sed 's|/lib/firmware/||' | sort` from a host with the unpruned
package installed, or `releases/portage/isos/savedconfig/sys-kernel/linux-firmware`):

```sh
bash releases/portage/framework/savedconfig/sys-kernel/gen-fw-savedconfig.sh \
    <vanilla-file-list> \
    > releases/portage/framework/savedconfig/sys-kernel/linux-firmware
git add releases/portage/framework/savedconfig/sys-kernel/linux-firmware
git commit -sS
```

The generation script follows the same format as
`releases/portage/isos/savedconfig/sys-kernel/prune_firmwares.sh`: uncommented lines are
installed, `#`-prefixed lines are excluded.

## Kernel config

Framework lists **6.19 as the minimum kernel, 7.0+ recommended**
(<https://frame.work/laptop13pro?tab=linux>). Stable `gentoo-sources` is 6.18, so
`package.accept_keywords/framework` keywords `=sys-kernel/gentoo-sources-7.2*`. That entry is
framework-only; the admincd stays on the stable kernel.

The spec references `releases/kconfig/amd64/amd64-7.2.8-framework.config`: the previous
framework config migrated to gentoo-sources-7.2.8 with `make olddefconfig`, then
`releases/kconfig/amd64/fragments/framework.config` merged on top. See
`releases/kconfig/amd64/README.md` for the regeneration recipe. The fragment covers:

- `DRM_XE` (+ `INTEL_MEI_GSC_PROXY`/`PXP`/`HDCP`): Arc B390 Xe3 iGPU. `DRM_SIMPLEDRM` +
  `SYSFB_SIMPLEFB` keep a console on the GOP framebuffer until `xe` loads.
- `PINCTRL_INTEL_PLATFORM`: Panther Lake GPIO. Touchpad/touchscreen IRQs depend on it.
- `INTEL_IDLE`, `INT340X_THERMAL`, `INTEL_RAPL`, `INTEL_PMC_CORE`: idle states, thermal, power.
- `IWLMLD` + `BT_HCIBTUSB`: BE211 Wi-Fi 7 (iwlmld op mode) and Bluetooth.
- `HID_HAPTIC` + `HID_MULTITOUCH`, `I2C_HID_ACPI`, `INTEL_THC_HID`/`QUICKI2C`/`QUICKSPI`:
  haptic touchpad and in-cell touchscreen.
- `INTEL_ISH_HID` + `HID_SENSOR_ALS`: sensor hub (ambient light).
- `SND_SOC_SOF_PANTHERLAKE`, `SND_SOC_SOF_HDA_LINK`/`HDA_AUDIO_CODEC`,
  `SND_SOC_INTEL_SOUNDWIRE_SOF_MACH` (selects the SoundWire codecs incl. CS42L43/RT7xx):
  internal audio and HDMI/DP audio.
- `USB4`, `INTEL_IOMMU` (default on, Thunderbolt DMA protection), `TYPEC_UCSI`/`UCSI_ACPI`.
- `USB_VIDEO_CLASS`: webcam. `DRM_ACCEL_IVPU`: NPU.
- `CROS_EC_LPC` and friends: the `cros_ec_lpc` driver matches the `FRMWC004` ACPI device
  on Framework laptops. Backs battery charge thresholds (`CHARGER_CROS_CONTROL`,
  `CROS_EC_SYSFS`), `/dev/cros_ec`, keyboard backlight, and Type-C mux/connector info used by
  `app-laptop/framework_tool` and `power-profiles-daemon`.

This config was generated off-target (no Panther Lake hardware available), so it has not been
boot-tested. Once built on real hardware, run `host/tune-kernel.sh` from
`gentoo_initial_setup` to catch anything missing (e.g. exact touch controller variant,
fingerprint reader) and fold the result back into the fragment.

## intel-microcode

`sys-firmware/intel-microcode` is installed with `initramfs split-ucode -hostonly`.

The `initramfs` USE flag generates `/boot/intel-uc.img` for early microcode loading. The
bootloader must load it as the first initrd, before the main initramfs:

```
# GRUB example
initrd /boot/intel-uc.img /boot/initramfs-framework-*.img
```

## Fingerprint reader

`sys-auth/fprintd` (pulls in `sys-auth/libfprint`) is installed for the Windows
Hello/libfprint-compatible fingerprint reader. The global `pam` USE flag means fprintd is built
with PAM support, but `pam_fprintd.so` is **not** wired into `/etc/pam.d/system-auth` by
default — that's an opt-in step on the target machine (`fprintd-enroll`, then edit PAM config).

`dbus|default` was added to `stage4/rcadd` since fprintd (and `boltd`) are D-Bus system
services and need the message bus running.

## Framework hardware tools

`app-laptop/framework_tool` and `app-laptop/framework-tool-tui` are the upstream CLI/TUI
for battery charge limits, fan control, keyboard backlight, privacy-switch status, and
firmware versions. Both are `~amd64` only, so `package.accept_keywords/framework`
unmasks them. They talk to the EC via `/dev/cros_ec` (`CROS_EC_CHARDEV`) or sysfs
(`CROS_EC_SYSFS`) — see the kernel config section above.

`sys-power/power-profiles-daemon` exposes performance/balanced/power-saver switching via
`/sys/firmware/acpi/platform_profile`, which on this hardware is backed by the `cros_ec`
driver. Added to `stage4/rcadd` as `power-profiles-daemon|default` (requires `dbus`).

`sys-apps/fwupd` delivers BIOS/EC/retimer firmware updates via LVFS.
`package.use/fwupd` enables `uefi` (UEFI ESRT capsule updates — the main path for
Framework BIOS updates) and `nvme` (SSD firmware updates).
