[← Back to README](../README.md)

# `scripts/workspace-rename.sh`

Prompts for a new name for the focused niri workspace via a [fuzzel](https://codeberg.org/dnkl/fuzzel) dmenu.

Bound to `Ctrl+Shift+R` in [`niri/local/binds.kdl`](../niri/local/binds.kdl), symlinked to `~/.local/bin/workspace-rename` by [`init.sh`](./init.md).

## How it works

1. `niri msg -j workspaces` dumps all workspaces as JSON; `jq` picks out the `name` of the one with `is_focused: true` (empty string if it's unnamed).
2. That current name is fed to fuzzel both as the prompt text (`Rename (current: <name|none>): `) and as the picker's sole list entry — so you can hit Enter to keep it as-is, or just type over it to replace it.
3. If the result is non-empty, `niri msg action set-workspace-name "<name>"` renames the focused workspace. Cancelling the dialog (`Esc`) or submitting an empty string leaves the name unchanged.
