[← Back to README](../README.md)

# `init.sh`

`init.sh` is meant to be run **once**, right after a fresh [archinstall](https://wiki.archlinux.org/title/Archinstall) with [niri](https://github.com/YaLTeR/niri) as the compositor. It is not meant to be re-run on an already-configured system. It's not interactive by design beyond a single confirmation prompt — what gets installed/linked is controlled by config arrays (`PACKAGES`, `FLATPAKS`, `AUR_PACKAGES`, `DOTFILE_LINKS`, `MODELS`, etc.) at the top of the script.

> [!WARNING]
> `init.sh` installs packages system-wide, writes sudoers drop-ins, replaces existing configs/symlinks under `~/.config` (backing up the previous file first), and reboots your machine at the end. It's intended for a **fresh** Arch install right after `archinstall` — review the script before running it on an existing system.

## Usage

If you're cloning this repo, note that a fresh Arch install doesn't ship `git` by default. You can install it with `sudo pacman -S git`.

```bash
git clone https://github.com/singudotdev/dotfiles.git
cd dotfiles

# Run the initial setup script (as your normal user, not root — it calls sudo itself)
./init.sh
```

## What it does

1. **Pre-flight checks** — refuses to run as root, refuses to run on non-Arch systems, and verifies that `niri`, `polkit`, an nvidia driver package, and the `multilib` repo are already present (these are expected to come from `archinstall`). Aborts with a list of what's missing if any check fails.
2. **User confirmation** — prompts before proceeding with system changes.
3. **System update & package install** — `pacman -Syu --needed` with the packages listed in `PACKAGES`.
4. **Sudo configuration** — writes `/etc/sudoers.d/00_<user>` (full, still password-gated `ALL=(ALL) ALL` access) and `/etc/sudoers.d/10_defaults` (shorter timestamp timeout, `log_input`/`log_output` to `/var/log/sudo.log`), validating both with `visudo -c` before trusting them.
5. **Flatpak applications** — adds the Flathub remote if missing, then installs each app in `FLATPAKS`, skipping ones already installed.
6. **Install AUR packages** — clones each package in `AUR_PACKAGES` from the AUR and builds/installs it with `makepkg -si`. No AUR helper is used or required:
    - `brave-origin-bin` — de-Googled Brave build
7. **Install DankMaterialShell** — `curl -fsSL https://install.danklinux.com \| sh`.
8. **Symlink configuration files** — links each entry in `DOTFILE_LINKS` from the repo into `$HOME` (see table below). Any existing file/symlink at the target is backed up (`<target>.bak.<timestamp>`) instead of deleted.
9. **Disable Bluetooth auto-enable** — sets `AutoEnable=false` in `/etc/bluetooth/main.conf`, if Bluetooth is installed.
10. **Set git identity** — configures `user.name` and `user.email` globally from `GIT_NAME`/`GIT_EMAIL`.
11. **Install Claude Code** — `curl -fsSL https://claude.ai/install.sh \| sh`.
12. **Install and configure Ollama** — installs via `curl -fsSL https://ollama.com/install.sh \| sh`, sets ownership/permissions on `/var/lib/ollama`, writes a systemd drop-in (`/etc/systemd/system/ollama.service.d/override.conf`) from `OLLAMA_NUM_CTX`/`OLLAMA_FLASH_ATTENTION`/`OLLAMA_KEEP_ALIVE`, then enables and starts the service.
13. **Pull Ollama models** — pulls each model in `MODELS`:
    - `qwen2.5-coder:7b-base` — autocomplete / inline predictions (Zed edit_predictions)
    - `qwen2.5-coder:7b` — fast snippets chat model (Zed agent panel)
14. **Reboot** — after a 5-second countdown.

Non-critical steps (Flatpak installs, DankMaterialShell, Claude Code, Ollama model pulls, the Ollama service start) warn and continue on failure rather than aborting the whole script; package installation, sudoers setup, and the Ollama install itself are treated as fatal.

> [!NOTE]
> Step 10 defaults `GIT_NAME`/`GIT_EMAIL` to `singudotdev` / `contact@singu.dev`. If you clone or fork this repo, change those variables near the top of `init.sh` to your own name/email before running it.

## What gets symlinked

| Source | Target |
| --- | --- |
| `DankMaterialShell/` | `~/.config/DankMaterialShell` |
| `fish/` | `~/.config/fish` |
| `ghostty/` | `~/.config/ghostty` |
| `niri/` | `~/.config/niri` |
| `zed/` | `~/.config/zed` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `fetch/` | `~/.config/fetch` |
| `scripts/upgrade-aur.sh` | `~/.local/bin/upgrade-aur` |
| `scripts/clean-pkgs.sh` | `~/.local/bin/clean-pkgs` |
| `scripts/fix-zed-transparency.sh` | `~/.local/bin/fix-zed-transparency` |
