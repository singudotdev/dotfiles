[← Back to README](../README.md)

# `scripts/audio-switch.sh`

Fuzzel picker that switches the default PulseAudio/PipeWire output sink and moves active streams onto it. Wired up as the middle-click action on waybar's `pulseaudio` module in [`waybar/config.jsonc`](../waybar/config.jsonc).

Symlinked to `~/.local/bin/audio-switch` by [`init.sh`](./init.md).

## How it works

1. Lists sink descriptions and names via `pactl list sinks` / `pactl list short sinks`.

2. Shows the descriptions in a `fuzzel --dmenu` picker.

3. Sets the chosen sink as default with `pactl set-default-sink`, then moves every active sink-input onto it with `pactl move-sink-input`.

4. Fires a `notify-send` confirming the new output.

## Caveats

Reads through PipeWire's `pipewire-pulse` compatibility layer. Only switches output sinks — input/source switching isn't wired up.
