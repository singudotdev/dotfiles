[← Back to README](../README.md)

# `scripts/cpu-status.sh`

Emits CPU usage % and package temperature as the JSON line Waybar's [`custom` module](https://github.com/Alexays/Waybar/wiki/Module:-Custom) type expects. Wired up as `custom/cpu` in [`waybar/config.jsonc`](../waybar/config.jsonc), polled every 3 seconds.

Symlinked to `~/.local/bin/cpu-status` by [`init.sh`](./init.md).

## How it works

1. Reads the aggregate CPU line from `/proc/stat` twice, 0.3s apart, and computes usage % from the delta between the two samples (`(total - idle) / total`), including `iowait` in the idle bucket.

2. Finds the hwmon device whose `name` is `coretemp` and reads its `temp1_input` (package temperature, millidegrees C, divided down to whole degrees).

3. Prints `{"text": ..., "tooltip": ..., "class": ...}`, where `class` is `low` / `medium` (≥60%) / `high` (≥85%) — matched against thresholds in [`waybar/style.css`](../waybar/style.css) for color-coding.

## Caveats

The sensor is looked up by driver name rather than by `hwmonN` index, since indices depend on driver load order and change between boots. `coretemp` is Intel-only; on AMD, change the name to `k10temp`.

## Clicking the module

`on-click` opens [`bottom`](../bottom) (`btm`) in a floating Alacritty window (`--class dev.singu.btm-float`, matched by a window rule in [`niri/config.kdl`](../niri/config.kdl)), expanded straight to the CPU widget (`--default_widget_type cpu --expanded`). The `memory` and `custom/gpu` modules open the same popup on the `mem` widget instead — `btm` has no separate GPU widget; GPU stats live inside `mem`.

The popup is 100×30 **cells**, set per launch with `-o window.dimensions.columns=100 -o window.dimensions.lines=30`.
