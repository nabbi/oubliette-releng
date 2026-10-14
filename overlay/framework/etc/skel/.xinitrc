#!/bin/sh
# startx skips /etc/X11/xinit/xinitrc.d, so start the session bus here;
# dunst, wireplumber and firefox need it
if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
	exec dbus-run-session -- sh "$0" "$@"
fi

# pipewire, pipewire-pulse and wireplumber for this X session
gentoo-pipewire-launcher &

# lock the screen when elogind suspends (lid close) or the screensaver fires
xss-lock -- alock &

exec startfluxbox
