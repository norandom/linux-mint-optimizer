#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence

# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
	. /etc/profile
fi

if test -r ~/.profile; then
	. ~/.profile
fi

# Clear any stale session variables
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start a fresh dbus session for this display
eval $(dbus-launch --sh-syntax --exit-with-session)

# Optimize for bandwidth - disable compositing and effects
export XORG_BACKING_STORE=NotUseful

# Disable animations and effects for bandwidth optimization
gsettings set org.mate.Marco.general compositing-manager false 2>/dev/null || true
gsettings set org.mate.interface enable-animations false 2>/dev/null || true

# Start the session
test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec mate-session