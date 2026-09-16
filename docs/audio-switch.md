[← Back to README](../README.md)

# `scripts/audio-switch.sh`

Fuzzel-based picker to switch the default PulseAudio/PipeWire output sink, moving any currently-playing streams over to it. Wired up as the middle-click action on waybar's `pulseaudio` module in [`waybar/config.jsonc`](../waybar/config.jsonc) — left-click mutes output (via `swayosd-client`), right-click opens `pavucontrol` for the full mixer, middle-click opens this picker.

Symlinked to `~/.local/bin/audio-switch` by [`init.sh`](./init.md).

## How it works

1. Lists sink descriptions and names via `pactl list sinks` / `pactl list short sinks`.
2. Shows the descriptions in a `fuzzel --dmenu` picker.
3. Sets the chosen sink as default with `pactl set-default-sink`, then moves every active sink-input (playing stream) onto it with `pactl move-sink-input` so audio doesn't keep playing out the old device.
4. Fires a `notify-send` confirming the new output.

## Caveats

Reads through PipeWire's `pipewire-pulse` PulseAudio-compatibility layer — needs it running (it does by default on this setup). Only switches output sinks; input/source switching isn't wired up.
