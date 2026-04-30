#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence

# /etc/pam.d/xrdp-sesman uses pam_env to load /etc/environment
# and /etc/default/locale, so locale + env are already set by the time
# this runs.

if test -r /etc/profile; then
	. /etc/profile
fi

if test -r ~/.profile; then
	. ~/.profile
fi

# Drop anything left over from a previous session
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Fresh dbus session for this display
eval $(dbus-launch --sh-syntax --exit-with-session)

# Cut down what xrdp has to push over the wire: no compositing, no animations.
export XORG_BACKING_STORE=NotUseful
gsettings set org.mate.Marco.general compositing-manager false 2>/dev/null || true
gsettings set org.mate.interface enable-animations false 2>/dev/null || true

# Start the session
test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec mate-session