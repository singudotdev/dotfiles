#!/bin/bash
# Chromium's OSCrypt only auto-picks libsecret on desktop environments it
# recognizes (GNOME, KDE...); niri isn't one, so it silently falls back to
# an unencrypted "basic_text" store. Force gnome-libsecret explicitly.
exec /usr/bin/element-desktop --password-store=gnome-libsecret "$@"
