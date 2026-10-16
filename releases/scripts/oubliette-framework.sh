#!/bin/bash
set -eu

# root_overlay is rsynced with -a, so files and the dirs above them keep the
# checkout's uid:gid
chown root:root /etc
chown -R root:root /etc/skel /etc/wpa_supplicant /etc/conf.d /etc/cron.weekly \
	/etc/kernel
chown root:root /etc/nftables.rules

# wpa_supplicant.conf collects psks (wpa_passphrase, wpa_cli save_config)
chmod 0600 /etc/wpa_supplicant/wpa_supplicant.conf
chmod 0600 /etc/nftables.rules

# the image ships no kernel; with gentoo-kernel in @world the laptop's first
# emerge -uDN @world builds it with /etc/kernel/config.d/framework.config
grep -qx 'sys-kernel/gentoo-kernel' /var/lib/portage/world \
	|| echo 'sys-kernel/gentoo-kernel' >> /var/lib/portage/world

exit 0
