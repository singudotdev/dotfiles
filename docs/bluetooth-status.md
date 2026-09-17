[← Back to README](../README.md)

# `scripts/bluetooth-status.sh`

Emits the Bluetooth adapter's power state as the JSON line Waybar's [`custom` module](https://github.com/Alexays/Waybar/wiki/Module:-Custom) type expects. Wired up as `custom/bluetooth` in [`waybar/config.jsonc`](../waybar/config.jsonc), polled every 5 seconds.

Symlinked to `~/.local/bin/bluetooth-status` by [`init.sh`](./init.md).

## How it works

1. Runs `bluetoothctl show` and checks for `Powered: yes`.
2. Prints `{"text": ..., "tooltip": ..., "class": ...}`, where `class` is `on` (green) or `off` (grey) — matched in [`waybar/style.css`](../waybar/style.css) for color-coding. The icon itself never changes, only its color.

## Requirements

Requires `bluetoothctl` from `bluez-utils`, part of the `PACKAGES` array in [`init.sh`](./init.md).

## Clicking the module

`on-click` toggles power: if the adapter is on, it turns it off; if it's off, it `rfkill unblock`s it first (bluez refuses `power on` on a soft-blocked adapter, and this machine's adapter is soft-blocked by default at boot) and then powers it on. `on-click-right` opens `blueman-manager` (already floated by an existing window-rule in [`niri/config.kdl`](../niri/config.kdl)) for pairing/device management — this replaces `blueman-applet`'s tray icon, which is disabled; see [docs/waybar-tray.md](./waybar-tray.md).
