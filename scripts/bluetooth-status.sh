#!/bin/bash
# Bluetooth adapter power state as JSON for waybar's custom module.
set -euo pipefail

class="off"
bluetoothctl show | grep -q "Powered: yes" && class="on"

printf '{"text": "", "tooltip": "Bluetooth: %s", "class": "%s"}\n' "$class" "$class"
