subarch: amd64
target: stage4
version_stamp: hardened-oubliette-framework-@TIMESTAMP@
rel_type: 23.0-hardened
profile: default/linux/amd64/23.0/hardened
compression_mode: pixz
snapshot_treeish: @TREEISH@
source_subpath: 23.0-hardened/stage3-amd64-oubliette-hardened-openrc-@TIMESTAMP@
portage_confdir: @REPO_DIR@/releases/portage/framework
repos: /var/db/repos/oubliette

# Global USE flags for the Framework 13 Pro image.
# Hardened profile doesn't set desktop defaults, so we add them explicitly.
# Kept intentionally minimal: no qt5/gnome/kde/systemd.
stage4/use:
	X
	alsa
	dbus
	dri
	elogind
	jpeg
	opengl
	pipewire
	png
	svg
	truetype
	udev
	unicode
	-bindist

stage4/packages:
	## --- Firmware ---
	# linux-firmware: pruned via savedconfig to Panther Lake Xe3 GPU blobs
	# (xe/ptl_*), BE211 Wi-Fi 7 (iwlwifi-bz-*), and Bluetooth (intel/ibt-0040,
	# intel/ibt-0041).
	sys-kernel/linux-firmware
	# sof-firmware: SOF audio firmware/topology is NOT part of linux-firmware;
	# required for the CS42L43 codec via SoundWire (CONFIG_SND_SOC_SOF_PANTHERLAKE).
	sys-firmware/sof-firmware
	# wireless-regdb: regulatory.db for cfg80211 — linux-firmware does not ship
	# this on this profile.
	net-wireless/wireless-regdb

	## --- Base system additions (mirrors server stage4) ---
	sys-boot/grub
	sys-apps/gptfdisk
	sys-apps/iproute2
	sys-apps/dmidecode
	sys-apps/ethtool
	sys-power/acpid
	sys-power/thermald
	net-misc/dhcpcd
	net-wireless/wpa_supplicant
	net-wireless/iw
	net-misc/openntpd
	net-misc/openssh
	net-misc/rsync
	net-misc/wget
	app-admin/sudo
	app-admin/syslog-ng
	app-admin/logrotate
	app-editors/vim
	app-misc/tmux
	app-portage/gentoolkit
	app-portage/genup
	app-eselect/eselect-repository
	app-admin/eclean-kernel
	sec-keys/openpgp-keys-gentoo-release
	dev-vcs/git
	dev-vcs/git-lfs
	sys-process/cronie
	dev-debug/strace

	## --- X.org server (minimal driver set) ---
	# xorg-server pulls libinput, dri, glamoregl; keep drivers lean.
	# Intel Xe uses the modesetting driver built into xorg-server — no separate
	# xf86-video-* package is needed or wanted for this hardware.
	x11-base/xorg-server
	x11-drivers/xf86-input-libinput

	## --- X utilities ---
	x11-apps/xrandr
	x11-apps/xset
	x11-apps/xsetroot
	x11-apps/xmodmap
	x11-apps/xprop
	app-misc/brightnessctl

	## --- Window manager and desktop shell ---
	x11-wm/fluxbox
	x11-misc/picom
	x11-misc/dunst
	x11-misc/xautolock
	x11-misc/alock
	media-gfx/feh

	## --- Terminal ---
	# xterm: featureful and minimal. rxvt-unicode is lighter if preferred.
	x11-terms/xterm

	## --- Fonts (minimal but readable) ---
	media-fonts/dejavu
	media-fonts/liberation-fonts

	## --- Audio ---
	# pipewire replaces pulseaudio; wireplumber is the session manager.
	media-libs/alsa-lib
	media-sound/alsa-utils
	media-video/pipewire
	media-video/wireplumber

	## --- Applications ---
	# mpv is the lightweight video choice vs vlc
	media-video/mpv
	# zathura: minimal PDF viewer; zathura-pdf-mupdf provides the backend
	app-text/zathura
	app-text/zathura-pdf-mupdf
	# Firefox: no lighter X browser worth shipping in Gentoo
	www-client/firefox

	## --- Games ---
	games-roguelike/evilhack

	## --- Storage ---
	sys-block/nvme-cli

	## --- Thunderbolt ---
	# bolt: userspace authorization daemon for Thunderbolt 4 / USB4 devices.
	sys-apps/bolt

	## --- Microcode ---
	# Intel Core Ultra Series 3 (Panther Lake) requires intel-microcode for
	# early-boot ucode loading; initramfs USE creates /boot/intel-uc.img to
	# prepend to the initrd so the kernel loads it before any driver init.
	# Confirm the merged intel-microcode version includes Panther Lake CPUID
	# microcode (20260210_p20260211 or newer covers it).
	sys-firmware/intel-microcode

	## --- Crypto / auth ---
	app-crypt/gnupg
	app-crypt/pinentry

	## --- Fingerprint reader ---
	# fprintd pulls in libfprint; the global "pam" USE flag wires up
	# pam_fprintd.so for opt-in fingerprint login/sudo via /etc/pam.d.
	sys-auth/fprintd

	## --- Framework hardware tools ---
	# framework_tool / framework-tool-tui: battery charge limits, fan
	# control, keyboard backlight, privacy-switch status, firmware
	# versions. Talks to the cros_ec_lpc kernel driver (CONFIG_CROS_EC*).
	app-laptop/framework_tool
	app-laptop/framework-tool-tui
	# fwupd: BIOS/EC/retimer firmware updates via LVFS (uefi USE for ESRT
	# capsule updates, nvme USE for SSD firmware updates).
	sys-apps/fwupd
	# power-profiles-daemon: performance/balanced/power-saver switching via
	# /sys/firmware/acpi/platform_profile (backed by CROS_EC on this
	# hardware).
	sys-power/power-profiles-daemon

stage4/rcadd:
	acpid|default
	net.lo|default
	netmount|default
	sshd|default
	cronie|default
	syslog-ng|default
	thermald|default
	wpa_supplicant|default
	# dbus: system bus required by boltd, fprintd, and power-profiles-daemon
	dbus|default
	boltd|default
	power-profiles-daemon|default
	# Start pipewire via user session, not rc — see fsscript or ~/.xinitrc

boot/kernel: gentoo
boot/kernel/gentoo/sources: gentoo-sources
# Framework 13 Pro (Panther Lake / Core Ultra Series 3) kernel config.
# Adds DRM_XE (Arc B390 Xe3 iGPU), SOF + SoundWire + CS42L43 audio,
# I2C HID ACPI touchscreen, and USB4 on top of the cloud config baseline.
boot/kernel/gentoo/config: @REPO_DIR@/releases/kconfig/amd64/amd64-6.18.33-framework.config
boot/kernel/gentoo/extraversion: framework
boot/kernel/gentoo/gk_kernargs: --all-ramdisk-modules

stage4/unmerge:
	sys-kernel/genkernel
	sys-kernel/gentoo-sources

stage4/empty:
	/root/.ccache
	/tmp
	/usr/portage/distfiles
	/usr/src
	/var/cache/edb/dep
	/var/cache/genkernel
	/var/cache/portage/distfiles
	/var/empty
	/var/run
	/var/state
	/var/tmp

stage4/rm:
	/etc/*-
	/etc/*.old
	/etc/ssh/ssh_host_*
	/root/.*history
	/root/.lesshst
	/root/.ssh/known_hosts
	/root/.viminfo
	/usr/share/genkernel
	/usr/lib64/python*/site-packages/gentoolkit/test/eclean/testdistfiles.tar.gz
