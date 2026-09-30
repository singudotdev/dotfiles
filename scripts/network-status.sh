#!/bin/bash
# WiFi radio/connection state (icon color) + network/VPN details (tooltip) as
# JSON for waybar's custom module.
set -euo pipefail

prefix_to_netmask() {
    local prefix=$1 mask="" i
    for ((i = 0; i < 4; i++)); do
        if ((prefix >= 8)); then
            mask+="255"
            prefix=$((prefix - 8))
        else
            mask+=$((256 - 2 ** (8 - prefix)))
            prefix=0
        fi
        ((i < 3)) && mask+="."
    done
    echo "$mask"
}

wifi_dev=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == "wifi" {print $1; exit}')
wifi_radio=$(nmcli radio wifi)
wifi_state=$(nmcli -t -f DEVICE,STATE device status | awk -F: -v d="$wifi_dev" '$1 == d {print $2; exit}')

if [[ "$wifi_radio" != "enabled" ]]; then
    icon=$(printf '\U000f0200')
    class="eth"
elif [[ "$wifi_state" == "connected" ]]; then
    icon=$(printf '')
    class="connected"
else
    icon=$(printf '')
    class="on"
fi

dev=$(ip route show default | awk '{print $5; exit}')
tooltip="No default route"
if [[ -n "$dev" ]]; then
    mapfile -t info < <(nmcli -g IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$dev")
    ip="${info[0]%/*}"
    mask=$(prefix_to_netmask "${info[0]#*/}")
    dns="${info[2]// | /, }"
    tooltip="Device: $dev\nIP: $ip\nGateway: ${info[1]}\nMask: $mask\nDNS: $dns"
fi

if [[ "$wifi_state" == "connected" ]]; then
    mapfile -t wifi_info < <(nmcli -t -f active,ssid,signal dev wifi | awk -F: '$1 == "yes" {print $2; print $3; exit}')
    wifi_ip=$(nmcli -g IP4.ADDRESS device show "$wifi_dev" 2>/dev/null | cut -d/ -f1)
    tooltip="$tooltip\n\nWiFi: ${wifi_info[0]}\nSignal: ${wifi_info[1]}%\nIP: $wifi_ip"
fi

vpn_line=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | awk -F: '$2 ~ /^(vpn|wireguard|openvpn|tun|tap)$/ {print; exit}')
if [[ -n "$vpn_line" ]]; then
    vpn_name="${vpn_line%%:*}"
    vpn_dev="${vpn_line##*:}"
    vpn_ip=$(nmcli -g IP4.ADDRESS device show "$vpn_dev" 2>/dev/null | cut -d/ -f1)
    endpoint=$(nmcli -g wireguard.peers connection show "$vpn_name" 2>/dev/null | grep -oP 'endpoint=\K[0-9.]+' | head -1)
    tooltip="$tooltip\n\nVPN: $vpn_name"
    [[ -n "$endpoint" ]] && tooltip="$tooltip\nServer IP: $endpoint"
    [[ -n "$vpn_ip" ]] && tooltip="$tooltip\nTunnel IP: $vpn_ip"
fi

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$icon" "$tooltip" "$class"
