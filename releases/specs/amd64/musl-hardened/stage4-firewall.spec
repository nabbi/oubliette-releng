subarch: amd64
target: stage4
version_stamp: hardened-oubliette-server-@TIMESTAMP@
rel_type: hardened
profile: default/linux/amd64/17.0/musl/hardened
compression_mode: pixz
snapshot: @TIMESTAMP@
source_subpath: musl-hardened/stage3-amd64-oubliette-musl-hardened-@TIMESTAMP@
portage_confdir: @REPO_DIR@/releases/portage/stages
repos: /var/db/repos/oubliette

stage4/use:
	#bindist
	bzip2
	idm
	ipv6
	urandom

stage4/packages:
	net-misc/dhcp
	sys-boot/grub
	sys-apps/dmidecode
	sys-apps/gptfdisk
	sys-apps/iproute2
	sys-devel/bc
	sys-power/acpid
	app-crypt/gentoo-keys
	#oubliette
    dev-lang/tcl
    app-admin/eclean-kernel
    app-portage/gentoolkit
    app-admin/sudo
    sys-auth/pam_yubico
    app-editors/vim
    app-misc/screen
    app-admin/syslog-ng
    app-admin/logrotate
    sys-process/cronie
    dev-util/strace
    net-analyzer/tcpdump
	net-analyzer/traceroute
	sys-apps/netplug
	sys-apps/ethtool
	net-misc/whois
	net-misc/sipcalc
	net-misc/frr
	net-firewall/ipset
	net-firewall/iptables
	net-firewall/nftables
	net-firewall/xtables-addons
	net-dns/bind-tools
	net-dns/ddclient

stage4/fsscript: @REPO_DIR@/releases/scripts/cloud-prep.sh
stage4/rcadd:
	acpid|default
	net.lo|default
	netmount|default
	sshd|default

boot/kernel: gentoo
boot/kernel/gentoo/sources: gentoo-sources
boot/kernel/gentoo/config: @REPO_DIR@/releases/kconfig/amd64/cloud-amd64-hardened.config
boot/kernel/gentoo/extraversion: openstack
boot/kernel/gentoo/gk_kernargs: --all-ramdisk-modules

# all of the cleanup...
stage4/unmerge:
	sys-devel/bc
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
	# Remove any generated stuff by genkernel
	/usr/share/genkernel
	# This is 3MB of crap for each copy
	/usr/lib64/python*/site-packages/gentoolkit/test/eclean/testdistfiles.tar.gz
