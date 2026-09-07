[← Back to README](../README.md)

# Fish functions

The [`fish`](../fish) config symlinked by `init.sh` ships a few custom functions under `fish/functions/`. Once linked, these are just commands available in any interactive shell.

| Command | Description |
| --- | --- |
| `cat` | Alias for [`bat`](https://github.com/sharkdp/bat) — `cat` with syntax highlighting and git integration. |
| `lcat` | Plain `/bin/cat`, for when you want the original behavior instead of `bat`. |
| `ll` | Alias for `eza -laagF --color --git` — a detailed, git-aware directory listing, including `.` and `..`. |
| `fetch` | Alias for `fastfetch -c ~/.config/fetch/fetch.jsonc` — prints the system info banner using this repo's [`fetch`](../fetch) config. |
| `supgrade` | Takes a pre/post btrfs snapshot pair (via `snapper`, on `root` and/or `home` if their configs exist) then runs `pacman -Syyu --noconfirm`, `flatpak update --assumeyes`, [`upgrade-aur`](./upgrade-aur.md), and [`clean-pkgs`](./clean-pkgs.md) — a full system upgrade in one command, undoable with `snapper undochange` if it breaks something. On a non-btrfs system (no `/etc/snapper/configs/root`), it skips snapshotting entirely and just runs the upgrade — see [`btrfs-optimize.sh`](./btrfs-optimize.md) to set the snapshot side up. Authenticates with `sudo -v` once up front and again at each phase boundary, so a long run doesn't re-prompt for a password partway through; `upgrade-aur`'s own per-package PKGBUILD review prompt is left as-is on purpose (a different kind of confirmation — reviewing unaudited third-party build scripts — not upgrade noise to suppress). |

`fish_prompt` and `fish_mode_prompt` are also defined there, but those customize the shell prompt itself rather than adding a command.
