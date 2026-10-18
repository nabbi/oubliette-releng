#!/bin/bash
set -eu


# ensure files copied from overlay hae correct uid:gid:perm
chown root:root /root
chmod 0700 /root

# ssh: overlay/admincd/root/.ssh/authorized_keys is gitignored and only ships
# when present in the local overlay; sshd refuses keys with unsafe perms
if [ -f /root/.ssh/authorized_keys ]; then
	chown root:root /root/.ssh
	chmod 0700 /root/.ssh

    chown root:root /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
fi

# wireless: overlay/admincd/etc/wpa_supplicant/wpa_supplicant.conf is gitignored
# and only ships when present in the local overlay
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
	chown root:root /etc/wpa_supplicant/wpa_supplicant.conf
	chmod 0600 /etc/wpa_supplicant/wpa_supplicant.conf

	# -M waits for a matching interface; iwlwifi registers wlan only after its
	# async firmware load, which can land after wpa_supplicant starts
	grep -q '^wpa_supplicant_args="-M' /etc/conf.d/wpa_supplicant ||
		echo 'wpa_supplicant_args="-M -iwl*"' >> /etc/conf.d/wpa_supplicant
	rc-update add wpa_supplicant default

	# autoconfig starts dhcpcd only if a NIC exists when it runs, which a
	# wireless-only machine may not have yet; manager mode picks wlan up later
	cat > /etc/local.d/wireless-dhcp.start <<-'EOT'
	#!/bin/sh
	pgrep -x dhcpcd >/dev/null || dhcpcd -b -h "$(hostname)"
	EOT
	chmod 0755 /etc/local.d/wireless-dhcp.start
	rc-update add local default
fi

# ca: overlay/admincd/usr/local/share/ca-certificates/*.crt are gitignored and
# only ship when present in the local overlay; the .example keeps the dir, so
# the dirs above it always arrive with the checkout's uid:gid
chown root:root /usr /usr/local /usr/local/share
chown -R root:root /usr/local/share/ca-certificates
if compgen -G '/usr/local/share/ca-certificates/*.crt' >/dev/null; then
	chmod 0644 /usr/local/share/ca-certificates/*.crt
	update-ca-certificates
fi

exit 0
