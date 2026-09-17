#!/bin/bash
# Power menu via fuzzel.
set -euo pipefail

choice=$(printf 'Lock\0icon\x1fsystem-lock-screen\nLogout\0icon\x1fsystem-log-out\nSuspend\0icon\x1fsystem-suspend\nReboot\0icon\x1fsystem-reboot\nShutdown\0icon\x1fsystem-shutdown' \
    | fuzzel --dmenu --prompt "Power menu: ")

case "$choice" in
    Lock)     gtklock ;;
    Logout)   niri msg action quit ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
