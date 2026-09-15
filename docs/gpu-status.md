[← Back to README](../README.md)

# `scripts/gpu-status.sh`

Emits NVIDIA GPU usage %, VRAM usage, and temperature as the JSON line Waybar's [`custom` module](https://github.com/Alexays/Waybar/wiki/Module:-Custom) type expects. Wired up as `custom/gpu` in [`waybar/config.jsonc`](../waybar/config.jsonc), polled every 3 seconds.

Symlinked to `~/.local/bin/gpu-status` by [`init.sh`](./init.md).

## How it works

1. Runs `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits` and reads the four comma-separated values.
2. Prints `{"text": ..., "tooltip": ..., "class": ...}`, where `class` is `low` / `medium` (≥50% util) / `high` (≥80% util) — matched against thresholds in [`waybar/style.css`](../waybar/style.css) for color-coding.

## Requirements

Requires an NVIDIA driver package with `nvidia-smi` on `$PATH` — installed as part of the `PACKAGES` array in [`init.sh`](./init.md) (`init.sh` also refuses to run if no nvidia driver package is detected). Not applicable on non-NVIDIA GPUs.
