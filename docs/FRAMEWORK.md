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
| Intel WiFi | `iwlwifi-bz-*` | BE211 (Wi-Fi 7) |
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

The spec references `releases/kconfig/amd64/amd64-6.18.33-framework.config`, built by
migrating the `amd64-6.6.30.config` cloud baseline forward to gentoo-sources-6.18.33 via
`make olddefconfig` and then enabling the drivers this hardware needs:

- `CONFIG_DRM_XE` — Intel Xe3 iGPU (Arc B390, Panther Lake)
- `CONFIG_SND_SOC_SOF_TOPLEVEL` + `CONFIG_SND_SOC_SOF_PANTHERLAKE` — Sound Open Firmware
- `CONFIG_SOUNDWIRE` + `CONFIG_SND_SOC_CS42L43*` / `CONFIG_MFD_CS42L43*` — SoundWire bus and
  CS42L43 codec
- `CONFIG_INPUT_TOUCHSCREEN` + `CONFIG_I2C_HID_ACPI` — 2.8K touchscreen
- `CONFIG_USB4` — Thunderbolt 4 / USB4 (used by `sys-apps/bolt`)
- `CONFIG_CROS_EC` + `CONFIG_CROS_EC_LPC` — ChromeOS EC over LPC. The
  `cros_ec_lpc` driver matches the `FRMWC004` ACPI device on Framework
  laptops (see its DMI table). Backs battery charge thresholds
  (`CONFIG_CROS_EC_SYSFS`), `/dev/cros_ec` (`CONFIG_CROS_EC_CHARDEV`),
  keyboard backlight (`CONFIG_CROS_KBD_LED_BACKLIGHT`), and Type-C
  mux/connector info (`CONFIG_CROS_EC_TYPEC`, `CONFIG_CROS_TYPEC_SWITCH`)
  used by `app-laptop/framework_tool` and `power-profiles-daemon`.

This config was generated off-target (no Panther Lake hardware available), so it has not been
boot-tested. Once built on real hardware, run `host/tune-kernel.sh` from
`gentoo_initial_setup` to catch anything missing (e.g. exact pinctrl/GPIO IDs, fingerprint
reader, Goodix touch controller variants) and refresh this config.

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
