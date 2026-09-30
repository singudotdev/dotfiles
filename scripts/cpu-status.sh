#!/bin/bash
# Combined CPU usage% + package temperature as JSON for waybar's custom module.
set -euo pipefail

read -r _ u1 n1 s1 i1 w1 irq1 sirq1 _ < /proc/stat
sleep 0.3
read -r _ u2 n2 s2 i2 w2 irq2 sirq2 _ < /proc/stat

idle1=$((i1 + w1))
idle2=$((i2 + w2))
total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1))
total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2))

totald=$((total2 - total1))
idled=$((idle2 - idle1))
usage=$(( (100 * (totald - idled)) / totald ))

hwmon_path=$(grep -l coretemp /sys/class/hwmon/hwmon*/name | head -n1 | xargs dirname)
temp_raw=$(cat "$hwmon_path/temp1_input")
temp=$(( temp_raw / 1000 ))

class="low"
[ "$usage" -ge 60 ] && class="medium"
[ "$usage" -ge 85 ] && class="high"

printf '{"text": "%s%% %s°C", "tooltip": "CPU: %s%%\\nTemp: %s°C", "class": "%s"}\n' \
    "$usage" "$temp" "$usage" "$temp" "$class"
