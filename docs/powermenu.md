[← Back to README](../README.md)

# `scripts/powermenu.sh`

Power menu via [fuzzel](https://codeberg.org/dnkl/fuzzel): Lock / Logout / Suspend / Reboot / Shutdown.

Bound to `Super+X` in [`niri/local/binds.kdl`](../niri/local/binds.kdl), symlinked to `~/.local/bin/powermenu` by [`init.sh`](./init.md).

## How it works

Builds a null-separated fuzzel dmenu list (`Lock`, `Logout`, `Suspend`, `Reboot`, `Shutdown`, each with a matching icon via fuzzel's `icon\x1f<name>` field) and dispatches on the choice:

| Choice | Action |
| --- | --- |
| Lock | `gtklock` |
| Logout | `niri msg action quit` |
| Suspend | `systemctl suspend` |
| Reboot | `systemctl reboot` |
| Shutdown | `systemctl poweroff` |

Dismissing the picker without a selection (`Esc`) leaves `choice` empty; it falls through the `case` with no match and the script exits normally without taking any action.
