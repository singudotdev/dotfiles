[← Back to README](../README.md)

# Bluetooth/network tray icon consolidation

`blueman-applet` (Bluetooth) and `nm-applet` (NetworkManager) used to register their own icons in Waybar's generic `tray` module, on the left side of the bar next to Element/ProtonVPN. Both are now replaced with dedicated `custom/bluetooth`, `custom/network`, and `custom/vpn` modules, grouped on the right next to `custom/notification` (the bell), using static [Nerd Font](https://www.nerdfonts.com/) glyphs instead of each app's own icon theme.

| Module | Behavior |
| --- | --- |
| `custom/bluetooth` | See [docs/bluetooth-status.md](./bluetooth-status.md) — green/grey by adapter power state. |
| `custom/network` | Static, always green — this machine is wired-ethernet-first and the module doesn't poll link state. `on-click` opens `nm-connection-editor`. |
| `custom/vpn` | Hidden unless a VPN-type connection (`vpn`/`wireguard`/`openvpn`/`tun`/`tap`) is active in `nmcli`, in which case it shows a lock icon. `on-click` opens `protonvpn-app`. |

## Disabling the old tray icons

Both `blueman-applet` and `nm-applet` are normally autostarted via XDG autostart `.desktop` files (`/etc/xdg/autostart/blueman.desktop`, `/etc/xdg/autostart/nm-applet.desktop`), picked up by systemd's `xdg-desktop-autostart-generator` as `app-<name>@autostart.service` units — `blueman-applet` was *also* explicitly `spawn-at-startup`'d from `niri/local/autostart.kdl`, redundantly.

[`autostart/`](../autostart) holds user-level overrides for the same filenames (`blueman.desktop`, `nm-applet.desktop`), each just `Hidden=true` — the standard XDG mechanism for suppressing a system-wide autostart entry per-user, symlinked to `~/.config/autostart` by [`init.sh`](./init.md). The explicit `spawn-at-startup "blueman-applet"` line was removed from `niri/local/autostart.kdl` since it's now redundant (and previously meant blueman-applet was actually started twice).

This only stops their tray icon/background service from launching — the packages (`blueman`, `network-manager-applet`) are left installed. Losing `nm-applet` also loses its WiFi-password-prompt secrets agent; `nmtui`/`nm-connection-editor` (both installed, but not currently in `init.sh`'s `PACKAGES`) are the fallback for connecting to a new secured network.

## Waybar gotcha: `exec-if` needs non-empty `exec` output

`custom/vpn` uses `exec-if` to gate visibility, but Waybar hides *any* `custom` module — regardless of `exec-if`'s exit code — if the paired `exec` command's stdout is empty (`src/modules/custom.cpp`: `if (output.out.empty() || exit_code != 0) hide()`). A static-icon module with no `{}`/`{text}` in `format` still needs `exec` to print *something* non-empty (e.g. `"exec": "echo vpn"`) — `"exec": "true"` silently hides the module forever, with no error logged anywhere.
