[← Back to README](../README.md)

# Bluetooth/network modules instead of tray icons

`blueman-applet` and `nm-applet` don't show tray icons. Waybar uses two custom modules instead, placed on the right next to `custom/notification` and drawn with [Nerd Font](https://www.nerdfonts.com/) glyphs:

| Module | Behavior |
| --- | --- |
| `custom/bluetooth` | Green/grey by adapter power state — see [bluetooth-status.md](./bluetooth-status.md). |
| `custom/network` | Colored by WiFi radio/connection state; tooltip shows IP/gateway/mask/DNS and VPN details — see [network-status.md](./network-status.md). |

VPN status and control come from ProtonVPN's own icon in the regular `tray` module.

## Tray placement

`tray` sits between the system-info modules (CPU/RAM/GPU/battery) and `custom/bluetooth`. Its separator, `custom/sep-tray`, only shows when the tray holds at least one icon (checked through `RegisteredStatusNotifierItems` on `org.kde.StatusNotifierWatcher` over D-Bus), so an empty tray doesn't leave a stray `|`.

## Why `custom/network` can't open `nm-applet`'s menu

`nm-applet`'s network list is a DBusMenu attached to its own tray icon; no other module can open it. `on-click-right` opens `nmtui` instead: a text-mode scan/connect/forget list in a floating Alacritty window (`dev.singu.nmtui-float`), built like the [`btm` popup](./cpu-status.md#clicking-the-module).

## Disabling the applets

Both applets autostart from `/etc/xdg/autostart/` (`blueman.desktop`, `nm-applet.desktop`), which systemd's `xdg-desktop-autostart-generator` turns into `app-<name>@autostart.service` units. [`autostart/`](../autostart), linked to `~/.config/autostart`, overrides both files with `Hidden=true`, the standard XDG way to disable a system autostart entry for one user.

The packages stay installed:

- `nmtui` asks for WiFi passwords itself, replacing `nm-applet`'s secrets agent. It ships with `networkmanager`.
- `nm-connection-editor` (`custom/network`'s `on-click`) is a dependency of `network-manager-applet`, not listed in `init.sh`'s `PACKAGES`.

## Waybar gotcha: `exec-if` needs non-empty `exec` output

Waybar hides a `custom` module whenever its `exec` prints nothing, whatever `exec-if` returns (`src/modules/custom.cpp`: `if (output.out.empty() || exit_code != 0) hide()`). That's why `custom/sep-tray` has `"exec": "echo sep"`: without it, the static `|` would stay hidden with no error logged.
