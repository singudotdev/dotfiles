[← Back to README](../README.md)

# Fish functions

The [`fish`](../fish) config symlinked by `init.sh` ships a few custom functions under `fish/functions/`. Once linked, these are just commands available in any interactive shell.

| Command | Description |
| --- | --- |
| `cat` | Alias for [`bat`](https://github.com/sharkdp/bat) — `cat` with syntax highlighting and git integration. |
| `lcat` | Plain `/bin/cat`, for when you want the original behavior instead of `bat`. |
| `ll` | Alias for `eza -lagF --color --git` — a detailed, git-aware directory listing. |
| `fetch` | Alias for `fastfetch -c ~/.config/fetch/fetch.jsonc` — prints the system info banner using this repo's [`fetch`](../fetch) config. |
| `supgrade` | Runs `pacman -Syyu`, `flatpak update`, [`upgrade-aur`](./upgrade-aur.md), and [`clean-pkgs`](./clean-pkgs.md) in sequence — a full system upgrade in one command. |

`fish_prompt` and `fish_mode_prompt` are also defined there, but those customize the shell prompt itself rather than adding a command.
