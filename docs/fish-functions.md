[← Back to README](../README.md)

# Fish functions

Custom functions in [`fish/functions/`](../fish/functions), available in any shell once [`init.sh`](./init.md) links the fish config.

| Command | Description |
| --- | --- |
| `cat` | Alias for [`bat`](https://github.com/sharkdp/bat) — `cat` with syntax highlighting and git integration. |
| `lcat` | Plain `/bin/cat`, for when you want the original behavior instead of `bat`. |
| `ll` | Alias for `eza -laagF --color --git` — a detailed, git-aware directory listing, including `.` and `..`. |
| `lsblkf` | Alias for `lsblk -o NAME,FSTYPE,FSVER,LABEL,FSAVAIL,FSUSE%,MOUNTPOINTS` — a filesystem-focused block device listing. |
| `fetch` | Alias for `fastfetch -c ~/.config/fetch/fetch.jsonc` — prints the system info banner using this repo's [`fetch`](../fetch) config. |
| `supgrade` | Full system upgrade in one command — see [below](#supgrade). |

## `supgrade`

Runs, in order:

1. `snapper` **pre** snapshot of `root` and/or `home` (only for configs that exist under `/etc/snapper/configs/`)
2. `reflector` — refreshes the mirrorlist (Spain, HTTPS, synced within 12h, sorted by rate)
3. `pacman -Syyu --noconfirm`
4. `flatpak update --assumeyes`
5. [`upgrade-aur`](./upgrade-aur.md)
6. [`clean-pkgs`](./clean-pkgs.md)
7. `snapper` **post** snapshot, paired with step 1

A bad upgrade can be reverted with `snapper undochange`, or by booting a snapshot from the GRUB menu once [`btrfs-optimize.sh`](./btrfs-optimize.md) has set that up. Without snapper configs (e.g. on XFS) the snapshot steps are skipped.

It runs `sudo -v` before each phase so the 5-minute sudo timeout doesn't re-prompt mid-run. `upgrade-aur`'s PKGBUILD review prompt is intentionally kept.

The shell prompt comes from [Starship](../starship) (`starship init fish | source` in `config.fish`), not from a fish function.
