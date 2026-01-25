#!/bin/bash
set -eu


# ensure files copied from overlay hae correct uid:gid:perm
chown root:root /root
chmod 0700 /root

# ssh daemon will refuse key authenticate if unsafe
if [ -f /root/.ssh/authorized_keys ]; then
	chown root:root /root/.ssh
	chmod 0700 /root/.ssh

    chown root:root /root/.ssh/authorized_keys
    chmod 0600 /root/.ssh/authorized_keys
fi

exit 0
