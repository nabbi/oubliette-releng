# Framework Workstation: AMD Ryzen AI Max+ PRO 495 (Strix Halo family, Radeon 8060S,
# up to 192 GB unified memory). Headless: it runs LLMs (ollama on Vulkan) and is
# administered over ssh. Same layout as the framework (13 Pro) spec.
subarch: amd64
target: stage4
version_stamp: hardened-oubliette-framework-workstation-splitusr-@TIMESTAMP@
# split-usr, like the hosts whose binary package pool it shares;
# its own rel_type keeps builds and the catalyst pkgcache apart from the
# merged-usr 23.0-hardened chain
rel_type: 23.0-hardened-splitusr
profile: default/linux/amd64/23.0/split-usr/hardened
compression_mode: pixz
snapshot_treeish: @TREEISH@
source_subpath: 23.0-hardened-splitusr/stage3-amd64-oubliette-hardened-openrc-splitusr-@TIMESTAMP@
portage_confdir: @REPO_DIR@/releases/portage/framework-workstation
repos: /var/db/repos/oubliette

# Global USE flags for the Framework Workstation image (Ryzen AI Max+ PRO 495,
# headless LLM host): no X, no desktop, no audio. Kept minimal: no systemd.
stage4/use:
	dbus
	elogind
	udev
	unicode
	vulkan
	-bindist

stage4/packages:
	## --- Firmware ---
	# linux-firmware: pruned via savedconfig (package.use/linux-firmware) to the
	# Strix Halo iGPU (amdgpu gc_11_5_x, psp/smu 14, sdma/vcn/dcn), XDNA NPU,
	# AMD microcode, RTL8126 5GbE and MediaTek MT7925 (RZ717) Wi-Fi/Bluetooth.
	# Microcode comes in linux-firmware (amd-ucode); no separate package.
	sys-kernel/linux-firmware
	# regulatory.db for cfg80211
	net-wireless/wireless-regdb

	## --- Boot: encrypted root (LUKS2 + LVM), initramfs via dracut ---
	# installkernel runs dracut on every kernel install (package.use/boot)
	sys-kernel/installkernel
	sys-kernel/dracut
	sys-fs/cryptsetup
	sys-fs/lvm2
	# tpm2-tools: unseal a TPM-held LUKS key (AMD fTPM, TCG_CRB) from the
	# initramfs, with a PIN as the TPM object's auth value
	app-crypt/tpm2-tools
	sys-boot/efibootmgr
	sys-fs/dosfstools

	## --- Base system additions (mirrors server stage4) ---
	sys-boot/grub
	sys-apps/gptfdisk
	sys-apps/iproute2
	sys-apps/dmidecode
	sys-apps/ethtool
	net-misc/dhcpcd
	net-wireless/wpa_supplicant
	net-wireless/iw
	net-misc/chrony
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
	sys-process/htop
	sys-apps/lm-sensors
	sys-apps/pciutils
	sys-apps/usbutils
	# pambase: the stage3 build lacks USE=elogind and stage4 doesn't merge
	# --deep, so name it here or logins get no elogind session
	sys-auth/pambase
	net-firewall/nftables
	dev-debug/strace
	app-shells/bash-completion
	net-misc/mosh
	dev-util/ccache
	net-fs/nfs-utils

	## --- Storage ---
	sys-apps/nvme-cli
	sys-apps/fwupd

	## --- GPU and LLM runtime ---
	# Mesa with radv (Vulkan) for the Radeon 8060S iGPU; vulkaninfo to check it
	media-libs/mesa
	dev-util/vulkan-tools
	# nvtop: GPU load and memory (amdgpu)
	sys-process/nvtop
	# ollama: model server, runs on ggml's Vulkan backend (package.use/llm);
	# its init script runs it as the ollama user. Not started by the image.
	sci-ml/ollama

stage4/rcadd:
	# elogind: login sessions
	elogind|boot
	# lvm: activate vg0 (the initramfs only activates what root needs)
	lvm|boot
	nftables|default
	chronyd|default
	net.lo|default
	sshd|default
	cronie|default
	syslog-ng|default
	dhcpcd|default
	# dbus: system bus for fwupd and elogind
	dbus|default

stage4/root_overlay: @REPO_DIR@/overlay/framework-workstation/
stage4/fsscript: @REPO_DIR@/releases/scripts/oubliette-framework-workstation.sh

# No kernel in the image: the host builds sys-kernel/gentoo-kernel (in @world
# via the fsscript) with the fragment the root_overlay puts in
# /etc/kernel/config.d/. No global USE=dist-kernel here: it makes
# linux-firmware pull virtual/dist-kernel and build the kernel in
# build_packages. Enable it on the host.

stage4/empty:
	/root/.ccache
	/tmp
	/usr/portage/distfiles
	/var/cache/edb/dep
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
	/usr/lib64/python*/site-packages/gentoolkit/test/eclean/testdistfiles.tar.gz
