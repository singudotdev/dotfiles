<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0D1B2A,100:1B263B&height=180&section=header&text=dotfiles&fontSize=44&fontColor=64FFDA&fontAlignY=35&fontFamily=Courier%20New&desc=Arch%20Linux%20%C2%B7%20niri%20%C2%B7%20Hibrid%20AI&descAlignY=58&descSize=16&descColor=8892B0&animation=fadeIn" width="100%"/>

![niri](https://img.shields.io/badge/niri-0D1B2A?style=for-the-badge)
![DankMaterialShell](https://img.shields.io/badge/DankMaterialShell-0D1B2A?style=for-the-badge)
![fish](https://img.shields.io/badge/fish-0D1B2A?style=for-the-badge)
![ghostty](https://img.shields.io/badge/ghostty-0D1B2A?style=for-the-badge)
![starship](https://img.shields.io/badge/starship-0D1B2A?style=for-the-badge)
![zed](https://img.shields.io/badge/zed-0D1B2A?style=for-the-badge)
![AI](https://img.shields.io/badge/AI-0D1B2A?style=for-the-badge)

</div>

Personal dotfiles for an Arch Linux desktop running [niri](https://github.com/YaLTeR/niri) as the Wayland compositor, styled with [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

## What's inside

| Directory | Description |
| --- | --- |
| [`DankMaterialShell`](./DankMaterialShell) | Configuration for the DankMaterialShell desktop shell |
| [`bottom`](./bottom) | Config for [bottom](https://github.com/ClementTsang/bottom), a terminal system monitor |
| [`fetch`](./fetch) | Config for the system info fetch tool ([fastfetch](https://github.com/fastfetch-cli/fastfetch)) |
| [`fish`](./fish) | Config for the [fish](https://fishshell.com/) shell |
| [`ghostty`](./ghostty) | Config for the [Ghostty](https://ghostty.org/) terminal emulator |
| [`niri`](./niri) | Config for the [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor |
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

## Scripts

| Script | Description | Docs |
| --- | --- | --- |
| `init.sh` | One-time bootstrap: installs packages and symlinks configs into place | [docs/init.md](./docs/init.md) |
| `scripts/mount.sh` | Interactive helper to add a storage device to `/etc/fstab` | [docs/mount.md](./docs/mount.md) |
| `scripts/upgrade-aur.sh` | On-demand checker/rebuilder for AUR packages installed outside an AUR helper | [docs/upgrade-aur.md](./docs/upgrade-aur.md) |
| `scripts/clean-pkgs.sh` | Clears the pacman/Flatpak caches and removes orphaned packages | [docs/clean-pkgs.md](./docs/clean-pkgs.md) |

## License
[MIT](./LICENSE) — feel free to reuse or fork anything here.

<div align="center">
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1B263B,100:0D1B2A&height=100&section=footer"/>
</div>
