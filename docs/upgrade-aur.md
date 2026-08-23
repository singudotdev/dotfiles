[← Back to README](../README.md)

# `scripts/upgrade-aur.sh`

The packages in `AUR_PACKAGES` (see step 6 of [`init.sh`](./init.md)) are installed from the AUR rather than through an AUR helper, so nothing auto-updates them. `upgrade-aur.sh` is a manual, on-demand replacement for that: run it whenever you want to check for new releases. It has its own `PACKAGES` array (defaults to the same packages as `init.sh`'s `AUR_PACKAGES`).

It deliberately doesn't run unattended (no systemd timer, no passwordless sudo): automating the final `pacman -U` step would need a NOPASSWD sudoers rule broad enough to double as a privilege-escalation path, since `pacman -U` runs the package's install scriptlets as root regardless of which file is handed to it.

> [!NOTE]
> Requires `jq`, which is already installed by `init.sh`'s package list. `init.sh` also symlinks it to `~/.local/bin/upgrade-aur` (no `.sh`, so it behaves like a regular binary on `PATH`), so after setup it's callable from anywhere as `upgrade-aur`. The [`supgrade`](./fish-functions.md) fish function runs it together with `pacman -Syu`, `flatpak update`, and `clean-pkgs`.

## Usage

Run this whenever you want to check for (and install) newer releases of the AUR packages:

```bash
./scripts/upgrade-aur.sh
```

## What it does

For each package:

1. **Checks versions** — compares the installed version (`pacman -Q`) against the latest version on the AUR (via the AUR RPC API). Skips to the next package if they already match, or if the package isn't installed.
2. **Rebuilds if newer** — if an update is available, clones the AUR package fresh, shows the `PKGBUILD` for review, then builds and installs it with `makepkg -si` (prompting for your sudo password as usual).
