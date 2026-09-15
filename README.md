<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0D1B2A,100:1B263B&height=180&section=header&text=dotfiles&fontSize=44&fontColor=64FFDA&fontAlignY=35&fontFamily=Courier%20New&desc=Arch%20Linux%20%C2%B7%20niri%20%C2%B7%20Hibrid%20AI&descAlignY=58&descSize=16&descColor=8892B0&animation=fadeIn" width="100%"/>

![niri](https://img.shields.io/badge/niri-0D1B2A?style=for-the-badge)
![waybar](https://img.shields.io/badge/waybar-0D1B2A?style=for-the-badge)
![matugen](https://img.shields.io/badge/matugen-0D1B2A?style=for-the-badge)
![fish](https://img.shields.io/badge/fish-0D1B2A?style=for-the-badge)
![ghostty](https://img.shields.io/badge/ghostty-0D1B2A?style=for-the-badge)
![starship](https://img.shields.io/badge/starship-0D1B2A?style=for-the-badge)
![zed](https://img.shields.io/badge/zed-0D1B2A?style=for-the-badge)
![AI](https://img.shields.io/badge/AI-0D1B2A?style=for-the-badge)

</div>

Personal dotfiles for an Arch Linux desktop running [niri](https://github.com/YaLTeR/niri) as the Wayland compositor. No bundled third-party shell — the bar, launcher, notifications, lock screen, OSDs, and clipboard are separate, official-Arch-repo-only tools wired together directly, with [matugen](https://github.com/InioX/matugen) generating a matching color scheme for all of them (plus fish, GTK, Ghostty, Zed, and Starship) from the current wallpaper.

## What's inside

| Directory | Description |
| --- | --- |
| [`niri`](./niri) | Config for the [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor (`local/` holds the split-out fragments included from `config.kdl`) |
| [`waybar`](./waybar) | Config for [Waybar](https://github.com/Alexays/Waybar), the top bar |
| [`fuzzel`](./fuzzel) | Config for [fuzzel](https://codeberg.org/dnkl/fuzzel), the app launcher and dmenu prompts (power menu, workspace rename, clipboard picker) |
| [`swaync`](./swaync) | Config for [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter), notifications + history panel |
| [`gtklock`](./gtklock) | Config for [gtklock](https://github.com/jovanlanik/gtklock), the lock screen |
| [`swayosd`](./swayosd) | Config for [SwayOSD](https://github.com/ErikReider/SwayOSD), the volume/brightness/mic on-screen display |
| [`matugen`](./matugen) | [matugen](https://github.com/InioX/matugen) config and templates — generates the color scheme for every tool listed here plus fish/GTK/Ghostty/Zed/Starship from the current wallpaper (Zed's syntax highlighting is the one exception: a fixed Monokai-style palette, kept readable independent of the wallpaper) |
| [`gtk-3.0`](./gtk-3.0), [`gtk-4.0`](./gtk-4.0) | `settings.ini` for GTK's icon theme ([Tela circle Dracula](https://github.com/vinceliuice/Tela-circle-icon-theme)) and dark preference; `gtk.css` overrides the default Adwaita blue accent/selection color with matugen's primary color |
| [`bottom`](./bottom) | Config for [bottom](https://github.com/ClementTsang/bottom), a terminal system monitor |
| [`fetch`](./fetch) | Config for the system info fetch tool ([fastfetch](https://github.com/fastfetch-cli/fastfetch)) |
| [`fish`](./fish) | Config for the [fish](https://fishshell.com/) shell |
| [`ghostty`](./ghostty) | Config for the [Ghostty](https://ghostty.org/) terminal emulator |
| [`starship`](./starship) | Config for the [Starship](https://starship.rs/) shell prompt |
| [`zed`](./zed) | Config for the [Zed](https://zed.dev/) editor |

## Quick start

```bash
git clone https://github.com/singudotdev/dotfiles.git
cd dotfiles

# Run the initial setup script (as your normal user, not root — it calls sudo itself)
./init.sh
```

> [!WARNING]
> `init.sh` installs packages system-wide, writes sudoers drop-ins, replaces existing configs/symlinks under `~/.config` (backing up the previous file first), and reboots your machine at the end. It's intended for a **fresh** Arch install right after `archinstall` — review [docs/init.md](./docs/init.md) before running it on an existing system.
>
> `init.sh` itself doesn't care whether `archinstall` set up XFS or btrfs. If you chose **btrfs**, run `./scripts/btrfs-optimize.sh` once after the post-`init.sh` reboot to apply compression, scrub, and snapshot tuning (`init.sh` will print a reminder if it detects a btrfs root). On XFS, skip it — there's nothing for that script to do, and `supgrade` will just run the upgrade without snapshotting.

## Scripts

| Script | Description | Docs |
| --- | --- | --- |
| `init.sh` | One-time bootstrap: installs packages and symlinks configs into place | [docs/init.md](./docs/init.md) |
| `scripts/mount-disk.sh` | Interactive helper to add a storage device to `/etc/fstab` and symlink its folders into `$HOME` | [docs/mount-disk.md](./docs/mount-disk.md) |
| `scripts/btrfs-optimize.sh` | Tunes an existing btrfs root (compression, scheduler, scrub, snapper, Steam subvolume, Limine boot-menu snapshots) | [docs/btrfs-optimize.md](./docs/btrfs-optimize.md) |
| `scripts/upgrade-aur.sh` | On-demand checker/rebuilder for AUR packages installed outside an AUR helper | [docs/upgrade-aur.md](./docs/upgrade-aur.md) |
| `scripts/clean-pkgs.sh` | Clears the pacman/Flatpak caches and removes orphaned packages | [docs/clean-pkgs.md](./docs/clean-pkgs.md) |
| `scripts/wallpaper.sh` | Wallpaper daemon (`swaybg`) + picker (`zenity`, `Mod+Y`); applying an image also regenerates matugen's color scheme | [docs/wallpaper.md](./docs/wallpaper.md) |
| `scripts/powermenu.sh` | Power menu (`Super+X`) via fuzzel — lock/logout/suspend/reboot/shutdown | [docs/powermenu.md](./docs/powermenu.md) |
| `scripts/clipboard-picker.sh` | Clipboard history picker (`Mod+V`): `cliphist` + fuzzel dmenu | [docs/clipboard-picker.md](./docs/clipboard-picker.md) |
| `scripts/workspace-rename.sh` | Prompt to rename the focused niri workspace (`Ctrl+Shift+R`) | [docs/workspace-rename.md](./docs/workspace-rename.md) |
| `scripts/cpu-status.sh` | CPU usage+temperature waybar module (`/proc/stat` + hwmon) | [docs/cpu-status.md](./docs/cpu-status.md) |
| `scripts/gpu-status.sh` | NVIDIA GPU usage+VRAM+temperature waybar module (`nvidia-smi`) | [docs/gpu-status.md](./docs/gpu-status.md) |

## Fish functions

The `fish` config also adds a few commands to your shell (aliases like `cat`/`ll`, plus `supgrade` for a one-shot system upgrade). See [docs/fish-functions.md](./docs/fish-functions.md) for the full list.

## License
[MIT](./LICENSE) — feel free to reuse or fork anything here.

<div align="center">
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1B263B,100:0D1B2A&height=100&section=footer"/>
</div>
