#!/bin/bash
# Wallpaper daemon (swaybg) and picker (zenity, with thumbnail previews) for niri.
# Run with no args at startup to reapply the last saved wallpaper (or a solid
# fallback color). Run with "pick" to choose a new one from $WALLPAPER_DIR.
# Applying an image also regenerates the color scheme (matugen) for
# niri/waybar/swaync/fuzzel/gtklock.
set -euo pipefail

STATE_FILE="$HOME/.local/state/wallpaper"
FALLBACK_COLOR="131316"

apply() {
    local path="$1"
    pkill -x swaybg 2>/dev/null || true
    if [ -n "$path" ] && [ -f "$path" ]; then
        swaybg -i "$path" -m fill &
        disown
        matugen image "$path" -t scheme-fidelity -q || true
    else
        swaybg -c "$FALLBACK_COLOR" &
        disown
    fi
}

case "${1:-}" in
    pick)
        dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
        [ -d "$dir" ] || dir="$HOME/Pictures"
        path=$(zenity --file-selection \
            --title="Choose wallpaper" \
            --filename="$dir/" \
            --file-filter="Images | *.jpg *.jpeg *.png *.webp *.JPG *.JPEG *.PNG *.WEBP" 2>/dev/null || true)
        [ -n "$path" ] || exit 0
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "$path" > "$STATE_FILE"
        apply "$path"
        ;;
    *)
        apply "$(cat "$STATE_FILE" 2>/dev/null || true)"
        ;;
esac
