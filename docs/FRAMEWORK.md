# Framework 13 Pro Stage4

Custom hardened stage4 for the Framework 13 Pro (Intel Core Ultra Series 3 / Panther Lake,
e.g. Core Ultra X7 358H, with Arc B390 Xe3 graphics).

Built on top of the hardened OpenRC **split-usr** stage3 and supplemented by
[gentoo_initial_setup](https://github.com/nabbi/gentoo_initial_setup) tuned for this hardware.

## Spec

`releases/specs/amd64/hardened/stage4-openrc-23-framework.spec`

Added to `SET_hardened_openrc_23_splitusr_OPTIONAL_SPECS` in `tools/catalyst-auto-amd64.conf` — build it
by passing the optional set flag to the build script.

## split-usr

The stage4 uses `default/linux/amd64/23.0/split-usr/hardened`, to match split-usr hosts
it shares a binary package pool with. A package built on a merged-usr
host can hardcode `/usr/bin/...` paths that don't exist on split-usr hosts, so one binpkg
pool needs one layout.

The layout is fixed when stage1 builds its root, so the stage4 has its own chain:
`stage1-openrc-23-splitusr.spec` → `stage3-openrc-23-splitusr.spec` → this spec, all with
`rel_type: 23.0-hardened-splitusr`. That keeps builds (`builds/23.0-hardened-splitusr/`)
and the catalyst package cache (`packages/23.0-hardened-splitusr/`) apart from the
merged-usr `23.0-hardened` chain, which is no longer built. The admincd is built on the
split-usr chain too, and lands in `builds/23.0-hardened-splitusr/`. The stage1 seed is upstream's
`stage3-amd64-openrc-splitusr` (`tools/download-stage3-seed.sh`); there is no hardened
split-usr autobuild, and stage1 rebuilds everything under the hardened profile anyway.

Build artifacts are named `stage4-amd64-hardened-oubliette-framework-splitusr-<timestamp>`.

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
| Intel WiFi | `iwlwifi-sc-*`, `iwlwifi-bz-*` | BE211 (Wi-Fi 7) loads `iwlwifi-sc-a0-wh-b0-cNNN`; kernel 7.2 accepts `-c102`..`-c106` (stable 20260622 ships up to `-c103`) |
| Realtek USB NIC | `rtl_nic/rtl815[36]*` | Ethernet Expansion Card (RTL8156B) and RTL8153 docks: r8152 PHY patches |
| Intel Bluetooth | `intel/ibt-*` (incl. `-pci`/`-iml`) | CNVi Bluetooth (paired with BE211; PCIe via `btintel_pcie`) |
| Intel ISH | `intel/ish/ish_ptl*` | Sensor hub firmware, loaded by the host on Panther Lake |
| Intel NPU | `intel/vpu/vpu_50xx*` | Panther Lake NPU (`DRM_ACCEL_IVPU`) |
| Intel DSP | `intel/dsp_fw*` | Legacy SST/ME subsystem firmware |

SOF audio firmware/topology (`sof-hda-generic` for the ALC285) is **not** part of
`linux-firmware` — it ships separately as `sys-firmware/sof-firmware` (see `stage4/packages`
in the spec). The regulatory database (`regulatory.db`) similarly comes from
`net-wireless/wireless-regdb`, not `linux-firmware`, on this profile.

To regenerate `releases/portage/framework/savedconfig/sys-kernel/linux-firmware` after a
`linux-firmware` version bump, run against a vanilla file list (e.g.
`find /lib/firmware ! -type d -printf '%P\n' | sort` (symlinks included) from a host with the unpruned
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

A savedconfig edit does not change the package version or USE flags, so catalyst's `pkgcache`
would happily reinstall a linux-firmware binpkg pruned by the old list. `tools/oubliette-build.sh`
deletes the cached linux-firmware binpkgs at the start of every full build for that reason; when
building by hand, remove `packages/*/*/sys-kernel/linux-firmware/` from the catalyst storedir first.

To check on the laptop which firmware the driver wants, `dmesg | grep iwlwifi` prints the
`minimum version required` / `maximum version supported` names after `no suitable firmware found!`.

## Kernel config

Framework lists **6.19 as the minimum kernel, 7.0+ recommended**
(<https://frame.work/laptop13pro?tab=linux>). Stable `gentoo-kernel` is 6.18, so
`package.accept_keywords/framework` keywords `=sys-kernel/gentoo-kernel-7.2*` (and the
matching `virtual/dist-kernel`).

The image ships **no kernel**; the spec has no `boot/kernel`. The laptop builds the
dist-kernel `sys-kernel/gentoo-kernel` itself: Gentoo's distribution config plus
`hardened-base.config` (`USE=hardened` from the profile). The root_overlay installs
`overlay/framework/etc/kernel/config.d/framework.config`, and the `kernel-build` eclass merges
it last, so the first build and every `emerge -u gentoo-kernel` after it use it. There is no full `.config` to maintain any more.
After a kernel bump, check that no fragment symbol is dropped (recipe in
`releases/kconfig/amd64/README.md`). Against gentoo-kernel-7.2.8 all 107 survive. The fragment covers:

- `DRM_XE` (+ `INTEL_MEI_GSC_PROXY`/`PXP`/`HDCP`): Arc B390 Xe3 iGPU. `DRM_SIMPLEDRM` +
  `SYSFB_SIMPLEFB` keep a console on the GOP framebuffer until `xe` loads.
- `PINCTRL_INTEL_PLATFORM`: Panther Lake GPIO. Touchpad/touchscreen IRQs depend on it.
- `INTEL_IDLE`, `INT340X_THERMAL`, `INTEL_RAPL`, `INTEL_PMC_CORE`: idle states, thermal, power.
- `IWLMLD` + `BT_INTEL_PCIE`: BE211 Wi-Fi 7 (iwlmld op mode) and Bluetooth, which is attached
  over PCIe on Panther Lake (`0xE476`), not USB.
- `HID_HAPTIC` + `HID_MULTITOUCH`, `I2C_HID_ACPI`, `INTEL_THC_HID`/`QUICKI2C`/`QUICKSPI`:
  haptic touchpad and in-cell touchscreen.
- `INTEL_ISH_HID` + `HID_SENSOR_ALS`: sensor hub (ambient light). The readings are in
  `/sys/bus/iio`; there is no auto-brightness daemon, as `iio-sensor-proxy` is only in GURU
  and nothing under fluxbox would consume it.
- `SND_SOC_SOF_PANTHERLAKE`, `SND_SOC_SOF_HDA_LINK`/`HDA_AUDIO_CODEC`,
  `SND_SOC_INTEL_SKL_HDA_DSP_GENERIC_MACH`: internal audio and HDMI/DP audio. On real hardware
  the analog codec is a Realtek ALC285 on the HDA link (internal mic through the codec), so
  SOF uses the HDA generic machine driver. If SOF misbehaves, `snd_intel_dspcfg.dsp_driver=1`
  falls back to plain `snd_hda_intel`, which works (verified on the admincd) and loses
  nothing without DMICs. `SND_SOC_INTEL_SOUNDWIRE_SOF_MACH` stays for other PTL codecs.
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

`sys-firmware/intel-microcode` is installed with `initramfs split-ucode -hostonly`. The
`initramfs` flag installs `/usr/lib/dracut/dracut.conf.d/15-intel-microcode.conf`
(`early_microcode=yes`), so dracut prepends the microcode to the initramfs (or UKI). The
`/boot/intel-uc.img` it also writes is unused with dracut; it goes away once `USE=dist-kernel`
is set on the laptop.

## initramfs and boot

`sys-kernel/installkernel` with `USE=dracut` (`package.use/boot`) runs dracut whenever a kernel
is installed. Upstream's diskimage confdir adds `grub`; the image leaves the layout flag to the
host. There is no initramfs in the image either; dracut generates it when the laptop installs
its kernel. `sys-fs/cryptsetup`, `sys-fs/lvm2` (`USE=lvm`) and `lvm|boot` are in the image for
a LUKS2 -> LVM root.

Deploying to the laptop (LUKS UUID, `kernel_cmdline`, signed UKI with sbctl and systemd-boot) is
host-specific and documented on the wiki page `Gentoo_laptop_install`. Write
`/etc/dracut.conf.d/` and the installkernel layout USE flags before the first kernel build;
after changing them later, regenerate with `emerge --config sys-kernel/gentoo-kernel`.

The image does **not** set `USE=dist-kernel` globally. With it, linux-firmware and
intel-microcode depend on `virtual/dist-kernel`, so catalyst would build gentoo-kernel during
`build_packages`. Set it in `make.conf` on the laptop after install, so firmware and
microcode updates regenerate the initramfs.

The fsscript adds `sys-kernel/gentoo-kernel` to `@world`, so the laptop's first
`emerge -uDN @world` builds and installs the kernel.

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
Framework BIOS updates) and `policykit` (wheel users can run `fwupdmgr`). The NVMe plugin is
always built.

## Services and session

`stage4/rcadd` starts `elogind` (boot; seats, lid/suspend, power button, `XDG_RUNTIME_DIR`),
`zram-init` (boot; zstd swap of a quarter of RAM), `nftables` (`/etc/nftables.rules`: inbound
dropped except ssh, ICMP and DHCPv6), `ntpd` (openntpd), `dhcpcd` alongside `wpa_supplicant`,
and `bluetooth` (`net-wireless/bluez`). acpid is not installed; elogind handles the lid and
power button.

`wpa_supplicant` runs with `-M -iwl*` (`/etc/conf.d/wpa_supplicant`), so it waits for the
iwlwifi interface that appears only after the async firmware load. Add networks with
`wpa_passphrase` or `wpa_cli`; `releases/scripts/oubliette-framework.sh` (`stage4/fsscript`)
keeps `/etc/wpa_supplicant/wpa_supplicant.conf` at 0600 and resets the overlay's ownership.
A weekly cron job runs `fstrim --all`.

`sys-auth/pambase` is in `stage4/packages` so it is rebuilt with `USE=elogind`: catalyst's
stage4 merge is not `--deep`, and the stage3's pambase would leave logins without an elogind
session (no seat, no `XDG_RUNTIME_DIR`, no rootless Xorg or PipeWire).
`media-libs/libva-intel-media-driver` provides VA-API (iHD) for Xe3 hardware video decode.

PipeWire runs per user rather than from rc. `overlay/framework/etc/skel/.xinitrc`
(`stage4/root_overlay`) re-execs itself under `dbus-run-session` (`startx` skips
`xinitrc.d`, where the session bus would otherwise start), then starts
`gentoo-pipewire-launcher`, `xss-lock -- alock` (locks before suspend) and `startfluxbox`, so new
users get audio and a session bus with `startx`.
