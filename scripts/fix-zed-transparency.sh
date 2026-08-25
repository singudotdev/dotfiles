#!/bin/bash
set -euo pipefail

# Matugen regenerates zed/themes/dank-zed-theme.json from the current
# wallpaper colors (see init.sh's matugenTemplateZed), wiping the "DankShell
# Dark Transparent" theme's transparency tuning back to matugen's opaque-ish
# defaults. Run this after a wallpaper/theme change to reapply it.

THEME_FILE="$HOME/.config/zed/themes/dank-zed-theme.json"
THEME_NAME="DankShell Dark Transparent"

# Bars stay more see-through; the editor/panel/terminal workspace stays more
# solid so code is easier to read; context menus are fully opaque so popups
# don't blend into whatever's behind them.
BAR_KEYS=(status_bar.background title_bar.background title_bar.inactive_background toolbar.background tab_bar.background tab.inactive_background tab.active_background)
# "background" is deliberately not in this list: the bare key "background"
# also matches each entry in the theme's "players" array (multiplayer cursor
# colors), so it's handled separately below by line position instead of name.
WORKSPACE_KEYS=(surface.background panel.background editor.background editor.gutter.background editor.subheader.background terminal.background)
BAR_ALPHA="99"       # ~60% opacity
WORKSPACE_ALPHA="BF" # 75% opacity

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }

[ -f "$THEME_FILE" ] || fail "$THEME_FILE not found. Is the zed config symlinked?"

start="$(grep -n "\"name\": \"$THEME_NAME\"" "$THEME_FILE" | head -1 | cut -d: -f1)"
[ -n "$start" ] || fail "Could not find the \"$THEME_NAME\" theme in $THEME_FILE"

end="$(awk -v s="$start" 'NR>s && /"name":/{print NR; exit}' "$THEME_FILE")"
[ -n "$end" ] || end="$(wc -l < "$THEME_FILE")"

log "Patching \"$THEME_NAME\" (lines $start-$end)..."

# Sets a key's color alpha suffix in-place, keeping whatever base color
# matugen generated (0 or 2 trailing hex digits is always the existing alpha).
set_alpha() {
    local key="${1//./\\.}" alpha="$2"
    sed -i -E "${start},${end}s/(\"${key}\": \"#[0-9A-Fa-f]{6})[0-9A-Fa-f]{0,2}\",/\1${alpha}\",/" "$THEME_FILE"
}

# The top-level "background" field immediately follows "surface.background"
# in matugen's template output; found by position, not by key name, since
# the bare key "background" also appears in each "players" array entry
# (multiplayer cursor colors) and those must be left untouched.
surface_line="$(awk -v s="$start" -v e="$end" 'NR>=s && NR<=e && /"surface\.background"/{print NR; exit}' "$THEME_FILE")"
[ -n "$surface_line" ] || fail "Could not find surface.background in the theme block"
bg_line=$((surface_line + 1))
sed -n "${bg_line}p" "$THEME_FILE" | grep -qE '"background": (null|"#[0-9A-Fa-f]{6}[0-9A-Fa-f]{0,2}"),' \
    || fail "Line $bg_line isn't the expected top-level \"background\" field"

base_color="$(sed -n "${surface_line}p" "$THEME_FILE" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)"
sed -i -E "${bg_line}s/\"background\": (null|\"#[0-9A-Fa-f]{6}[0-9A-Fa-f]{0,2}\"),/\"background\": \"${base_color}${WORKSPACE_ALPHA}\",/" "$THEME_FILE"

for key in "${WORKSPACE_KEYS[@]}"; do
    set_alpha "$key" "$WORKSPACE_ALPHA"
done

for key in "${BAR_KEYS[@]}"; do
    set_alpha "$key" "$BAR_ALPHA"
done

set_alpha "elevated_surface.background" ""

# Real per-window blur isn't available under niri; this just tells Zed to
# request it (harmless if unsupported) rather than rendering fully opaque.
sed -i -E "${start},${end}s/\"background\.appearance\": \"[a-z]+\",/\"background.appearance\": \"blurred\",/" "$THEME_FILE"

ok "Zed transparency reapplied"
