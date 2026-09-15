[← Back to README](../README.md)

# `scripts/cpu-status.sh`

Emits CPU usage % and package temperature as the JSON line Waybar's [`custom` module](https://github.com/Alexays/Waybar/wiki/Module:-Custom) type expects. Wired up as `custom/cpu` in [`waybar/config.jsonc`](../waybar/config.jsonc), polled every 3 seconds.

Symlinked to `~/.local/bin/cpu-status` by [`init.sh`](./init.md).

## How it works

1. Reads the aggregate CPU line from `/proc/stat` twice, 0.3s apart, and computes usage % from the delta between the two samples (`(total - idle) / total`), including `iowait` in the idle bucket.
2. Reads the package temperature from `/sys/class/hwmon/hwmon3/temp1_input` (millidegrees C, divided down to whole degrees).
3. Prints `{"text": ..., "tooltip": ..., "class": ...}`, where `class` is `low` / `medium` (≥60%) / `high` (≥85%) — matched against thresholds in [`waybar/style.css`](../waybar/style.css) for color-coding.

## Caveats

`hwmon3` is hardcoded to whatever hwmon index this workstation's CPU package-temperature sensor currently enumerates as. hwmon indices are assigned by driver load order and **are not guaranteed stable** across reboots or kernel/driver updates. If the module stops updating its temperature (or `cat`s an empty/missing file), check `ls /sys/class/hwmon/*/name` to find which `hwmonN` now reports the CPU package temp (e.g. `k10temp` on AMD, `coretemp` on Intel) and update the path in the script.
