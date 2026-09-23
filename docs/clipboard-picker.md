[← Back to README](../README.md)

# `scripts/clipboard-picker.sh`

Clipboard history picker: pipes [`cliphist`](https://github.com/sentriz/cliphist)'s history into a [fuzzel](https://codeberg.org/dnkl/fuzzel) dmenu, then decodes and copies whatever you pick back onto the clipboard with `wl-copy`.

Bound to `Mod+V` in [`niri/local/binds.kdl`](../niri/local/binds.kdl), symlinked to `~/.local/bin/clipboard-picker` by [`init.sh`](./init.md).

## How it works

```bash
cliphist list | fuzzel --dmenu --prompt "Clipboard: " | cliphist decode | wl-copy
```

1. `cliphist list` prints each history entry as `<id>\t<preview>`.

2. fuzzel shows those lines in a dmenu-style picker; the selected line (still `<id>\t<preview>`) is passed on.

3. `cliphist decode` turns the selected id back into the original clipboard content (text or image).

4. `wl-copy` places it on the Wayland clipboard.

## Requirements

- `cliphist`'s watchers must already be running to have anything to pick from — `niri/local/autostart.kdl` spawns `wl-paste --type text --watch cliphist store` and the same for `image` at startup.

- `wl-clipboard` (for `wl-copy`) and `fuzzel` — both installed by `init.sh`.
