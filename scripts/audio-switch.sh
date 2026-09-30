#!/bin/bash
# Fuzzel picker to switch the default PulseAudio/PipeWire output sink, moving
# active streams over to it. Wired up as the middle-click action on waybar's
# `pulseaudio` module.
set -euo pipefail

mapfile -t descs < <(pactl list sinks | awk -F': ' '/^\tDescription:/{print $2}')
mapfile -t names < <(pactl list short sinks | cut -f2)
current=$(pactl get-default-sink)

choice=$(printf '%s\n' "${descs[@]}" | fuzzel --dmenu --prompt "Audio Output> ")
[ -z "$choice" ] && exit 0

target=""
for i in "${!descs[@]}"; do
    if [[ "${descs[$i]}" == "$choice" ]]; then
        target="${names[$i]}"
        break
    fi
done

[ -z "$target" ] && exit 0
[[ "$target" == "$current" ]] && exit 0

pactl set-default-sink "$target"

mapfile -t inputs < <(pactl list short sink-inputs | cut -f1)
for input in "${inputs[@]}"; do
    pactl move-sink-input "$input" "$target" 2>/dev/null || true
done

notify-send -i audio-speakers-symbolic "Audio Output" "$choice"
