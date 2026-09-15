#!/bin/bash
# NVIDIA GPU status (usage/VRAM/temp) as JSON for waybar's custom module.
set -euo pipefail

read -r util mem_used mem_total temp < <(
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits | tr -d ','
)

class="low"
[ "$util" -ge 50 ] && class="medium"
[ "$util" -ge 80 ] && class="high"

printf '{"text": "%s%% %s°C", "tooltip": "GPU: %s%%\\nVRAM: %s / %s MiB\\nTemp: %s°C", "class": "%s"}\n' \
    "$util" "$temp" "$util" "$mem_used" "$mem_total" "$temp" "$class"
