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

| Directory / File | Description |
| --- | --- |
| [`DankMaterialShell`](./DankMaterialShell) | Configuration for the DankMaterialShell desktop shell |
| [`bottom`](./bottom) | Config for [bottom](https://github.com/ClementTsang/bottom), a terminal system monitor |
| [`fetch`](./fetch) | Config for the system info fetch tool ([fastfetch](https://github.com/fastfetch-cli/fastfetch)) |
| [`fish`](./fish) | Config for the [fish](https://fishshell.com/) shell |
| [`ghostty`](./ghostty) | Config for the [Ghostty](https://ghostty.org/) terminal emulator |
| [`niri`](./niri) | Config for the [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor |
| [`starship`](./starship) | Config for the [Starship](https://starship.rs/) shell prompt |
| [`zed`](./zed) | Config for the [Zed](https://zed.dev/) editor |
| [`init.sh`](./init.sh) | Bootstrap script: installs packages and symlinks configs into place |
| [`mount.sh`](./mount.sh) | Interactive helper to add a storage device to `/etc/fstab` |
| [`update-aur-packages.sh`](./update-aur-packages.sh) | On-demand checker/rebuilder for AUR packages installed outside an AUR helper |

## What `init.sh` does

`init.sh` is meant to be run **once**, right after a fresh [archinstall](https://wiki.archlinux.org/title/Archinstall) with [niri](https://github.com/YaLTeR/niri) as the compositor. It is not meant to be re-run on an already-configured system. It's not interactive by design beyond a single confirmation prompt — what gets installed/linked is controlled by config arrays (`PACKAGES`, `FLATPAKS`, `AUR_PACKAGES`, `DOTFILE_LINKS`, `MODELS`, etc.) at the top of the script.

Running it will:

1. **Pre-flight checks** — refuses to run as root, refuses to run on non-Arch systems, and verifies that `niri`, `polkit`, an nvidia driver package, and the `multilib` repo are already present (these are expected to come from `archinstall`). Aborts with a list of what's missing if any check fails.
2. **User confirmation** — prompts before proceeding with system changes.
3. **System update & package install** — `pacman -Syu --needed` with the packages listed in `PACKAGES`.
4. **Sudo configuration** — writes `/etc/sudoers.d/00_<user>` (full, still password-gated `ALL=(ALL) ALL` access) and `/etc/sudoers.d/10_defaults` (shorter timestamp timeout, `log_input`/`log_output` to `/var/log/sudo.log`), validating both with `visudo -c` before trusting them.
5. **Flatpak applications** — adds the Flathub remote if missing, then installs each app in `FLATPAKS`, skipping ones already installed.
6. **Install AUR packages** — clones each package in `AUR_PACKAGES` from the AUR and builds/installs it with `makepkg -si`. No AUR helper is used or required:
    - `brave-origin-bin` — de-Googled Brave build
    - `voltius-bin` — local-first SSH/SFTP/Serial client with E2EE sync and plugins, no account required
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

### What gets symlinked

| Source | Target |
| --- | --- |
| `DankMaterialShell/` | `~/.config/DankMaterialShell` |
| `fish/` | `~/.config/fish` |
| `ghostty/` | `~/.config/ghostty` |
| `niri/` | `~/.config/niri` |
| `zed/` | `~/.config/zed` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `fetch/` | `~/.config/fetch` |

## What `mount.sh` does

`mount.sh` is an interactive script that helps you add a storage device to `/etc/fstab` and mount it persistently. Running it will:

1. **Show connected storage devices** — displays `lsblk` output with name, size, type, label, mount point, filesystem type, and UUID.
2. **Prompt for device and mount point** — asks for the device name (e.g., `sda1`) and an absolute mount path (e.g., `/mnt/data`).
3. **Create the mount point** — makes the directory if it doesn't exist and sets ownership to your user.
4. **Retrieve UUID and filesystem type** — looks up the device's UUID and filesystem type via `lsblk`.
5. **Add the fstab entry** — if an entry for that UUID doesn't already exist, backs up the current fstab to `/etc/fstab.bak` and appends `UUID=<uuid> <mount_point> <fstype> defaults 0 2`. Running the script again for the same device skips this step instead of adding a duplicate line.
6. **Reload systemd daemon** — runs `systemctl daemon-reload`.
7. **Mount everything** — runs `mount -a` to activate the new entry, warning (rather than failing silently) if it reports errors.

> [!NOTE]
> Run `mount.sh` as your normal user, not with `sudo`. It calls `sudo` itself for the individual steps that need root (creating the mount point, backing up and editing `/etc/fstab`, reloading systemd, mounting), so the mount point ends up owned by you instead of root.

## What `update-aur-packages.sh` does

The packages in `AUR_PACKAGES` (see step 6 of `init.sh`) are installed from the AUR rather than through an AUR helper, so nothing auto-updates them. `update-aur-packages.sh` is a manual, on-demand replacement for that: run it whenever you want to check for new releases. It has its own `PACKAGES` array (defaults to the same packages as `init.sh`'s `AUR_PACKAGES`) and, for each one:

1. **Checks versions** — compares the installed version (`pacman -Q`) against the latest version on the AUR (via the AUR RPC API). Skips to the next package if they already match, or if the package isn't installed.
2. **Rebuilds if newer** — if an update is available, clones the AUR package fresh, shows the `PKGBUILD` for review, then builds and installs it with `makepkg -si` (prompting for your sudo password as usual).

Once all packages are processed, it removes any orphaned dependencies left behind by the rebuilds.

It deliberately doesn't run unattended (no systemd timer, no passwordless sudo): automating the final `pacman -U` step would need a NOPASSWD sudoers rule broad enough to double as a privilege-escalation path, since `pacman -U` runs the package's install scriptlets as root regardless of which file is handed to it.

> [!NOTE]
> Requires `jq`, which is already installed by `init.sh`'s package list.

## Usage

> [!WARNING]
> `init.sh` installs packages system-wide, writes sudoers drop-ins, replaces existing configs/symlinks under `~/.config` (backing up the previous file first), and reboots your machine at the end. It's intended for a **fresh** Arch install right after `archinstall` — review the script before running it on an existing system.

### Initial setup with `init.sh`

If you're cloning this repo, note that a fresh Arch install doesn't ship `git` by default. You can install it with `sudo pacman -S git`.

```bash
git clone https://github.com/singudotdev/dotfiles.git
cd dotfiles

# Run the initial setup script (as your normal user, not root — it calls sudo itself)
./init.sh
```

### Mounting a new drive with `mount.sh`

If you have a new storage device, run this to mount it:

```bash
./mount.sh
```

### Checking for AUR package updates with `update-aur-packages.sh`

Run this whenever you want to check for (and install) newer releases of the AUR packages:

```bash
./update-aur-packages.sh
```

## License
[MIT](./LICENSE) — feel free to reuse or fork anything here.

<div align="center">
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1B263B,100:0D1B2A&height=100&section=footer"/>
</div>
