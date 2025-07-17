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

# Optimize for bandwidth - disable compositing and effects
export XORG_BACKING_STORE=NotUseful
export MATE_DESKTOP_SESSION_ID=

# Disable animations and effects for bandwidth optimization
gsettings set org.mate.Marco.general compositing-manager false 2>/dev/null || true
gsettings set org.mate.interface enable-animations false 2>/dev/null || true

test -x /etc/X11/Xsession && exec /etc/X11/Xsession
# exec /bin/sh /etc/X11/Xsession
mate-session
