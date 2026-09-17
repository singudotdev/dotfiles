[← Back to README](../README.md)

# `scripts/wallpaper.sh`

Wallpaper daemon ([`swaybg`](https://github.com/swaywm/swaybg)) and picker ([`zenity`](https://gitlab.gnome.org/GNOME/zenity) with thumbnail previews) for niri. Applying an image also regenerates the [matugen](https://github.com/InioX/matugen) color scheme used by every tool listed in [`matugen/config.toml`](../matugen/config.toml)'s `[templates.*]` entries.

Bound to `Mod+Y` (picker) in [`niri/local/binds.kdl`](../niri/local/binds.kdl), spawned with no arguments at startup by [`niri/local/autostart.kdl`](../niri/local/autostart.kdl), symlinked to `~/.local/bin/wallpaper` by [`init.sh`](./init.md).

## Usage

```bash
wallpaper        # reapply the last saved wallpaper (or a solid fallback color)
wallpaper pick    # choose a new wallpaper via a zenity file picker
```

## How it works

- **State**: the currently selected wallpaper's path is persisted to `~/.local/state/wallpaper`, a single line of plain text.
- **`pick`**: opens a zenity file selector rooted at `$WALLPAPER_DIR` (default `~/Pictures/Wallpapers`, falling back to `~/Pictures` if that doesn't exist), filtered to `*.jpg`/`*.jpeg`/`*.png`/`*.webp` (case-insensitive extensions). Cancelling the dialog exits with no changes. On a valid selection, the path is written to the state file and applied.
- **No args** (startup): reads the state file, if any, and applies it.
- **`apply()`**: kills any running `swaybg` (`pkill -x swaybg`), then either:
  - starts `swaybg -i <path> -m fill` (fill/crop-to-fit) for a real image, and regenerates the color scheme with `matugen image <path> -t scheme-tonal-spot -m smart -q`; or
  - starts `swaybg -c 131316` (a solid dark fallback color) if there's no valid path yet — e.g. first boot, before any wallpaper has ever been picked.

`matugen`'s regeneration failing (`|| true`) doesn't block the wallpaper itself from being applied.

## GTK apps

GTK only reads `gtk.css` once at startup. The `[templates.gtk4]` entry in `matugen/config.toml` carries a `post_hook` that restarts `waybar`, `swaync`, `nautilus`, and `protonvpn-app` after every regeneration so they pick up the new accent color. `protonvpn-app` also needs it for a separate reason: it doesn't reliably re-register its tray icon after `waybar` restarts. It's restarted with `--start-minimized` (ProtonVPN's own flag for staying tray-only) so this doesn't pop its window open on every wallpaper change.
