#!/bin/sh
# xrdp calls this on reconnect. The session is already there;
# returning 0 tells xrdp to attach to it.
exit 0