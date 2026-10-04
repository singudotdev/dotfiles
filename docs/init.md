[← Back to README](../README.md)

# `init.sh`

One-time bootstrap, run right after a fresh [archinstall](https://wiki.archlinux.org/title/Archinstall) with [niri](https://github.com/YaLTeR/niri) as the compositor. It isn't meant to be re-run. Apart from one confirmation prompt it's non-interactive; what it installs and links is set by the arrays at the top of the script (`PACKAGES`, `REDUNDANT_PACKAGES`, `CARGO_PACKAGES`, `FLATPAKS`, `AUR_PACKAGES`, `DOTFILE_LINKS`).

> [!WARNING]
> `init.sh` installs packages system-wide, writes sudoers drop-ins, replaces existing configs/symlinks under `~/.config` (backing up the previous file first), and reboots your machine at the end. It's intended for a **fresh** Arch install right after `archinstall` — review the script before running it on an existing system.

## Usage

A fresh Arch install doesn't include `git`; install it first with `sudo pacman -S git`.

```bash
git clone https://github.com/singudotdev/dotfiles.git
cd dotfiles

./init.sh   # as your normal user, not root — it calls sudo itself
```

> [!NOTE]
> `GIT_NAME`/`GIT_EMAIL` default to `singudotdev` / `contact@singu.dev`. If you fork this repo, change them at the top of `init.sh` first.

## What it does

1. **Pre-flight checks** — refuses to run as root, refuses to run on non-Arch systems, and verifies that `niri`, `polkit`, an nvidia driver package, and the `multilib` repo are already present (these are expected to come from `archinstall`). Aborts with a list of what's missing if any check fails.

2. **Confirmation** — asks before changing anything.

3. **System update & package install** — `pacman -Syu --needed` with the packages listed in `PACKAGES`. Everything comes from official Arch repos; AUR packages are handled in step 7.

4. **Install the Rust toolchain** — runs the official rustup installer (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh`) non-interactively with `-y --no-modify-path`, then `cargo install`s each crate in `CARGO_PACKAGES`:
    - `cargo-binstall` — installs prebuilt crate binaries instead of compiling them
    - `cargo-clean-recursive` — runs `cargo clean` across every project under a directory

    `--no-modify-path` because [`fish/conf.d/rustup.fish`](../fish/conf.d/rustup.fish) already adds cargo to `PATH`. Otherwise rustup would create a real `~/.config/fish` that step 8 then backs up and replaces.

5. **Sudo configuration** — writes `/etc/sudoers.d/00_<user>` (full, still password-gated `ALL=(ALL) ALL` access) and `/etc/sudoers.d/10_defaults` (shorter timestamp timeout, `log_input`/`log_output` to `/var/log/sudo.log`), validating both with `visudo -c` before trusting them.

6. **Flatpak applications** — adds the Flathub remote if missing, then installs each app in `FLATPAKS`, skipping ones already installed.

7. **Install AUR packages** — clones each package in `AUR_PACKAGES` from the AUR and builds/installs it with `makepkg -si`. No AUR helper is used or required:
    - `brave-origin-bin` — de-Googled Brave build

8. **Symlink configuration files** — links each entry in `DOTFILE_LINKS` into `$HOME` (see [table](#what-gets-symlinked)). An existing target is renamed to `<target>.bak.<timestamp>`, not deleted. Also seeds `~/.local/state/wallpaper` with the repo's wallpaper so [`wallpaper`](./wallpaper.md) has an image to apply on first boot.

9. **Disable GNOME Keyring's systemd socket** — masks `gnome-keyring-daemon.socket`. `ly`'s PAM config (`pam_gnome_keyring auto_start`) already starts and unlocks the daemon at login; the socket starts a second instance that crashes the first and leaves a locked, password-prompting one behind.

10. **Enable swaync** — enables `swaync.service` (tied to `graphical-session.target`). systemd is swaync's only launcher; a second instance from niri's `spawn-at-startup` makes the unit fail on every login.

11. **Disable Bluetooth auto-enable** — sets `AutoEnable=false` in `/etc/bluetooth/main.conf`, if Bluetooth is installed.

12. **Disable TPM NvPCR measurements** — masks `systemd-tpm2-setup-early.service`, `systemd-pcrproduct.service` and `systemd-pcrlogin@.service`. systemd 262 fails to create their TPM NV indexes, so they error on every boot. Unused with a passphrase-unlocked LUKS root; unmask before enrolling the TPM with `systemd-cryptenroll`.

13. **Set git identity** — configures `user.name` and `user.email` globally from `GIT_NAME`/`GIT_EMAIL`.

14. **Install Claude Code** — `curl -fsSL https://claude.ai/install.sh \| sh`. Zed uses it as its AI agent (`claude-acp` in [`zed/settings.json`](../zed/settings.json)).

15. **Set GTK dark theme** — `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`.

16. **Disable IPv6** — writes `/etc/sysctl.d/99-disable-ipv6.conf` (`net.ipv6.conf.{all,default,lo}.disable_ipv6 = 1`) and applies it with `sysctl --system`.

17. **Remove redundant packages** — `pacman -Rns` on whichever packages in `REDUNDANT_PACKAGES` are installed (pacman aborts if any listed package is missing, so absent ones are filtered out first). archinstall and niri's optional deps pull these in alongside the tools this setup uses instead:
    - `mako` — notifications are handled by swaync
    - `swaylock` — the lock screen is gtklock
    - `nano` — `EDITOR` is Zed, with vim as the terminal fallback

18. **Reboot** — after a 5-second countdown (`Ctrl+C` cancels). On the first login, niri's `spawn-at-startup` entries ([`niri/local/autostart.kdl`](../niri/local/autostart.kdl)) start waybar, swayosd, the wallpaper daemon and the cliphist watchers; systemd starts swaync; matugen generates the first color scheme.

Package installation, rustup and the sudoers setup abort the script on failure. Everything else (Flatpaks, cargo crates, AUR builds, Claude Code, redundant package removal) only warns and continues.

## After the reboot

If the root filesystem is **btrfs**, run [`./scripts/btrfs-optimize.sh`](./btrfs-optimize.md) once (`init.sh` prints a reminder). On XFS there's nothing to do; `supgrade` just skips snapshots.

## What gets symlinked

| Source | Target |
| --- | --- |
| `bottom/bottom.toml` | `~/.config/bottom/bottom.toml` |
| `fish/` | `~/.config/fish` |
| `alacritty/` | `~/.config/alacritty` |
| `niri/` | `~/.config/niri` |
| `waybar/` | `~/.config/waybar` |
| `fuzzel/` | `~/.config/fuzzel` |
| `swaync/` | `~/.config/swaync` |
| `swayosd/` | `~/.config/swayosd` |
| `gtklock/` | `~/.config/gtklock` |
| `gtk-3.0/settings.ini` | `~/.config/gtk-3.0/settings.ini` |
| `gtk-3.0/gtk.css` | `~/.config/gtk-3.0/gtk.css` |
| `gtk-4.0/settings.ini` | `~/.config/gtk-4.0/settings.ini` |
| `gtk-4.0/gtk.css` | `~/.config/gtk-4.0/gtk.css` |
| `matugen/` | `~/.config/matugen` |
| `zed/` | `~/.config/zed` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `fetch/` | `~/.config/fetch` |
| `autostart/` | `~/.config/autostart` |
| `assets/taskbar-icon.png` | `~/Pictures/logos/taskbar-icon.png` |
| `assets/taskbar-icon-grey.png` | `~/Pictures/logos/taskbar-icon-grey.png` |
| `assets/wallpaper.png` | `~/Pictures/wallpaper.png` |
| `scripts/upgrade-aur.sh` | `~/.local/bin/upgrade-aur` |
| `scripts/clean-pkgs.sh` | `~/.local/bin/clean-pkgs` |
| `scripts/powermenu.sh` | `~/.local/bin/powermenu` |
| `scripts/clipboard-picker.sh` | `~/.local/bin/clipboard-picker` |
| `scripts/workspace-rename.sh` | `~/.local/bin/workspace-rename` |
| `scripts/wallpaper.sh` | `~/.local/bin/wallpaper` |
| `scripts/gpu-status.sh` | `~/.local/bin/gpu-status` |
| `scripts/cpu-status.sh` | `~/.local/bin/cpu-status` |
| `scripts/element-desktop.sh` | `~/.local/bin/element-desktop` |
| `scripts/audio-switch.sh` | `~/.local/bin/audio-switch` |
| `scripts/bluetooth-status.sh` | `~/.local/bin/bluetooth-status` |
| `scripts/network-status.sh` | `~/.local/bin/network-status` |
