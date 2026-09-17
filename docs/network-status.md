[← Back to README](../README.md)

# `scripts/network-status.sh`

Emits WiFi radio/connection state plus the active connection's network details as the JSON line Waybar's [`custom` module](https://github.com/Alexays/Waybar/wiki/Module:-Custom) type expects. Wired up as `custom/network` in [`waybar/config.jsonc`](../waybar/config.jsonc), polled every 5 seconds.

Symlinked to `~/.local/bin/network-status` by [`init.sh`](./init.md).

## How it works

1. Reads `nmcli radio wifi` (radio on/off) and the WiFi device's connection state from `nmcli device status`, and picks an icon + `class`: an ethernet-plug icon, class `eth` (WiFi radio disabled — showing wired connectivity instead), or a WiFi icon with class `on` (radio enabled, not connected) or `connected` — matched in [`waybar/style.css`](../waybar/style.css) for color-coding (`eth`/`connected` green, `on` grey).
2. Finds the default-route device (`ip route show default`) and reads its `IP4.ADDRESS`/`IP4.GATEWAY`/`IP4.DNS` via `nmcli`, converting the CIDR prefix to a dotted-decimal netmask, for the tooltip.
3. If WiFi is connected, appends the active SSID, signal strength, and the WiFi device's own IP (`nmcli -t -f active,ssid,signal dev wifi` + `nmcli -g IP4.ADDRESS device show`) — shown whenever WiFi is connected, independent of whether it's the default-route device.
4. If a VPN-type connection (`vpn`/`wireguard`/`openvpn`/`tun`/`tap`) is active in `nmcli`, appends its name, WireGuard peer endpoint IP (parsed from `nmcli -g wireguard.peers`, stripping nmcli's own `\:` port-separator escaping), and tunnel IP to the tooltip.
5. Prints `{"text": ..., "tooltip": ..., "class": ...}`.

## Clicking the module

`on-click` opens `nm-connection-editor` (manual profile editing); `on-click-right` opens `nmtui` in a floating Ghostty popup (real WiFi scan/connect/forget — see [docs/waybar-tray.md](./waybar-tray.md) for why `nm-applet`'s own dropdown can't be reused); `on-click-middle` toggles the WiFi radio on/off (`nmcli radio wifi`).

## Caveats

The tooltip's IP/gateway/mask/DNS block follows the **default-route device** (on this machine, wired ethernet) — the WiFi block is separate and only appears when WiFi is actually connected, regardless of whether it's the default route.

The WireGuard endpoint-IP parsing is specific to WireGuard-backed VPN connections (this machine's ProtonVPN setup); other VPN backends won't have a `wireguard.peers` field and the tooltip will just omit the server-IP line.
