#!/bin/bash
# Prompt for a new name for the focused niri workspace.
# Shows the current name (if any) as the prompt text and as the sole list
# entry, so you can see it, keep it (select it), or type a new one instead.
set -euo pipefail

current=$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .name // ""')

name=$(printf '%s\n' "$current" | fuzzel --dmenu --prompt "Rename (current: ${current:-none}): ")
[ -n "$name" ] && niri msg action set-workspace-name "$name"
