[← Back to README](../README.md)

# Bluetooth/network tray icon consolidation

`blueman-applet` (Bluetooth) and `nm-applet` (NetworkManager) used to register their own icons in Waybar's generic `tray` module, on the left side of the bar next to Element/ProtonVPN. Both are now replaced with dedicated `custom/bluetooth` and `custom/network` modules, grouped on the right next to `custom/notification` (the bell), using [Nerd Font](https://www.nerdfonts.com/) glyphs instead of each app's own icon theme.

ProtonVPN's own tray icon (from `protonvpn-app`, still in the generic `tray` module) handles VPN status/management — no separate `custom/*` module for it.

The `tray` module itself sits between the sys-info block (CPU/RAM/GPU/battery) and `custom/bluetooth`/`custom/network`, not at the start of the right-hand group like Waybar's default. Its separator, `custom/sep-tray`, only renders while `tray` actually has an icon in it (checked via `RegisteredStatusNotifierItems` on `org.kde.StatusNotifierWatcher` over D-Bus), so an empty tray — e.g. Element and ProtonVPN both closed — doesn't leave a stray `|` with nothing to its left.

| Module | Behavior |
| --- | --- |
| `custom/bluetooth` | See [docs/bluetooth-status.md](./bluetooth-status.md) — green/grey by adapter power state. |
| `custom/network` | See [docs/network-status.md](./network-status.md) — icon color tracks WiFi radio/connection state; tooltip shows the active connection's IP/gateway/mask/DNS (plus VPN server/IP if active). |

## Why `custom/network` can't reuse `nm-applet`'s dropdown

`nm-applet`'s network list is a DBusMenu rendered by `nm-applet` itself as part of its own StatusNotifierItem — it's not a standalone menu another module's `on-click` can pop open. The only way to show it is for `nm-applet` to have a visible tray icon, which is exactly what got removed. `nmtui` (see [docs/network-status.md](./network-status.md) for how it's wired up) is the closest already-installed equivalent: a real scan/connect/forget list, just ncurses instead of graphical, opened in a floating Ghostty popup (`dev.singu.nmtui-float`, floated by a window-rule in [`niri/config.kdl`](../niri/config.kdl), same pattern as the `btm` popups).

## Disabling the old tray icons

Both `blueman-applet` and `nm-applet` are normally autostarted via XDG autostart `.desktop` files (`/etc/xdg/autostart/blueman.desktop`, `/etc/xdg/autostart/nm-applet.desktop`), picked up by systemd's `xdg-desktop-autostart-generator` as `app-<name>@autostart.service` units — `blueman-applet` was *also* explicitly `spawn-at-startup`'d from `niri/local/autostart.kdl`, redundantly.

[`autostart/`](../autostart) holds user-level overrides for the same filenames (`blueman.desktop`, `nm-applet.desktop`), each just `Hidden=true` — the standard XDG mechanism for suppressing a system-wide autostart entry per-user, symlinked to `~/.config/autostart` by [`init.sh`](./init.md). The explicit `spawn-at-startup "blueman-applet"` line was removed from `niri/local/autostart.kdl` since it's now redundant (and previously meant blueman-applet was actually started twice).

This only stops their tray icon/background service from launching — the packages (`blueman`, `network-manager-applet`) are left installed. Losing `nm-applet` also loses its WiFi-password-prompt secrets agent; `nmtui` prompts for the password itself when activating a secured network, so this is covered. `nmtui` ships with `networkmanager` itself, already an implicit prerequisite of this whole setup. `nm-connection-editor` (a separate package) isn't currently in `init.sh`'s `PACKAGES` array despite being relied on for `custom/network`'s `on-click` — a pre-existing gap, not introduced by this change.

## Waybar gotcha: `exec-if` needs non-empty `exec` output

Waybar hides *any* `custom` module — regardless of `exec-if`'s exit code — if the paired `exec` command's stdout is empty (`src/modules/custom.cpp`: `if (output.out.empty() || exit_code != 0) hide()`). `custom/sep-tray`'s `exec` (`echo sep`) exists solely to satisfy this — a static-format module with no `{}`/`{text}` placeholder still needs `exec` to print *something* non-empty, or it silently hides forever with no error logged anywhere.
