subarch: amd64
version_stamp: oubliette
target: livecd-stage1
rel_type: hardened
profile: default/linux/amd64/17.1/hardened
source_subpath: hardened/stage3-amd64-hardened-openrc-oubliette
compression_mode: pixz
portage_confdir: /opt/oubliette-releng/releases/portage/isos

livecd/use:
	alsa
	caps
	compile-locales
	fbcon
	filecaps
	ipv6
	livecd
	modules
	ncurses
	nls
	nptl
	pam
	portaudio
	readline
	socks5
	ssl
	unicode
	xml
	tcl

livecd/packages:
	app-accessibility/brltty
	app-accessibility/espeakup
	app-admin/hddtemp
	app-admin/pwgen
	app-admin/syslog-ng
	app-admin/sysstat
	app-admin/testdisk
	app-arch/bzip2
	app-arch/cpio
	app-arch/dpkg
	app-arch/gzip
	app-arch/mt-st
	app-arch/p7zip
	app-arch/pbzip2
	app-arch/tar
	app-arch/unrar
	app-arch/unzip
	app-backup/duplicity
	app-backup/fsarchiver
	app-benchmarks/bonnie
	app-benchmarks/bonnie++
	app-benchmarks/dbench
	app-benchmarks/iozone
	app-benchmarks/stress
	app-benchmarks/tiobench
	app-crypt/gnupg
	app-crypt/pinentry
	app-editors/emacs
	app-editors/hexcurse
	app-editors/hexedit
	app-editors/mg
	app-editors/nano
	app-editors/vim
	app-emacs/ebuild-mode
	app-emulation/cloud-init
	app-emulation/xen-tools
	app-misc/colordiff
	app-misc/livecd-tools
	app-misc/mc
	app-misc/pax-utils
	app-misc/screen
	app-misc/tmux
	app-portage/eix
	app-portage/gentoolkit
	app-portage/mirrorselect
	app-portage/portage-utils
	app-shells/bash-completion
	app-shells/gentoo-bashcomp
	app-shells/zsh
	app-text/tree
	app-text/dos2unix
	app-text/wgetpaste
	app-vim/gentoo-syntax
	dev-lang/perl
	dev-lang/python
	dev-vcs/git
	media-gfx/fbgrab
	media-sound/alsa-utils
	net-analyzer/iptraf-ng
	net-analyzer/openbsd-netcat
	net-analyzer/tcptraceroute
	net-analyzer/traceroute
	net-analyzer/traceroute-nanog
	net-analyzer/tcpdump
	net-analyzer/nmap
	net-dialup/mingetty
	net-dialup/minicom
	net-dialup/pptpclient
	net-dialup/rp-pppoe
	net-dns/bind-tools
	net-fs/cifs-utils
	net-fs/nfs-utils
	net-ftp/ftp
	net-ftp/ncftp
	net-irc/irssi
	net-misc/curl
	net-misc/dhcpcd
	net-misc/iputils
	net-misc/ndisc6
	net-misc/ntp
	net-misc/openssh
	net-misc/rdate
	net-misc/rsync
	net-misc/telnet-bsd
	net-misc/vconfig
	net-misc/wget
	net-misc/whois
	net-proxy/dante
	net-proxy/tsocks
	net-vpn/openvpn
	net-wireless/b43-fwcutter
	net-wireless/iw
	net-wireless/wireless-tools
	net-wireless/wpa_supplicant
	sys-apps/arrayprobe
	sys-apps/acl
	sys-apps/attr
	sys-apps/busybox
	sys-apps/cciss_vol_status
	sys-apps/chname
	sys-apps/coreutils
	sys-apps/dcfldd
	sys-apps/diffutils
	sys-apps/dmidecode
	sys-apps/dstat
	sys-apps/ethtool
	sys-apps/file
	sys-apps/findutils
	sys-apps/flashrom
	sys-apps/fxload
	sys-apps/gawk
	sys-apps/gptfdisk
	sys-apps/grep
	sys-apps/hdparm
	sys-apps/ipmitool
	sys-apps/iproute2
	sys-apps/less
	sys-apps/man-db
	sys-apps/man-pages
	sys-apps/man-pages-posix
	sys-apps/memtester
	sys-apps/mlocate
	sys-apps/netplug
	sys-apps/nvme-cli
	sys-apps/pciutils
	sys-apps/pcmciautils
	sys-apps/sdparm
	sys-apps/usbutils
	sys-apps/sed
	sys-apps/setserial
	sys-apps/sg3_utils
	sys-apps/smartmontools
	sys-apps/usbutils
	sys-apps/which
	sys-block/aoetools
	sys-block/fio
	sys-block/mtx
	sys-block/open-iscsi
	sys-block/parted
	sys-block/partimage
	sys-block/tw_cli
	sys-boot/grub
	sys-firmware/ipw2100-firmware
	sys-firmware/ipw2200-firmware
	sys-fs/bcache-tools
	sys-fs/btrfs-progs
	sys-fs/cryptsetup
	sys-fs/ddrescue
	sys-fs/dislocker
	sys-fs/dmraid
	sys-fs/dosfstools
	sys-fs/e2fsprogs
	sys-fs/exfat-utils
	sys-fs/extundelete
	sys-fs/f2fs-tools
	sys-fs/jfsutils
	sys-fs/lsscsi
	sys-fs/lvm2
	sys-fs/mac-fdisk
	sys-fs/mdadm
	sys-fs/multipath-tools
	sys-fs/ntfs3g
	sys-fs/reiserfsprogs
	sys-fs/xfsprogs
	sys-kernel/linux-firmware
	sys-libs/gpm
	sys-libs/libsmbios
	sys-power/acpid
	sys-process/htop
	sys-process/lsof
	sys-process/iotop
	sys-process/procps
	sys-process/psmisc
	www-client/links
	# tools
	app-forensics/cmospwd
	# networking
	net-analyzer/fping
	net-misc/iperf
	=net-misc/iperf-2*
	net-misc/sipcalc
	net-analyzer/hping
	net-analyzer/sslscan
	net-misc/socat
	net-ftp/atftp
	# dev
	dev-lang/tcl
	dev-tcltk/tcllib
	dev-tcltk/tls
	dev-tcltk/udp
	dev-tcltk/expect
	# coffee break
	games-roguelike/evilhack

snapshot_treeish: master

repos: /var/lib/layman/oubliette
