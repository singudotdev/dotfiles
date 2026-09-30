[← Back to README](../README.md)

# `scripts/upgrade-aur.sh`

Updates AUR packages. They're built with plain `makepkg` instead of an AUR helper, so nothing else updates them.

Symlinked to `~/.local/bin/upgrade-aur` by [`init.sh`](./init.md). [`supgrade`](./fish-functions.md#supgrade) runs it as part of every upgrade. Requires `jq`.

## Usage

```bash
upgrade-aur
```

The packages to track are listed in the script's own `PACKAGES` array: `init.sh`'s `AUR_PACKAGES` plus any AUR packages installed elsewhere. Add to it whenever you `makepkg -si` something by hand.

## What it does

For each package:

1. **Checks versions** — compares the installed version (`pacman -Q`) against the latest version on the AUR (via the AUR RPC API). Skips to the next package if they already match, or if the package isn't installed.

2. **Rebuilds if newer** — if an update is available, clones the AUR package fresh, shows the `PKGBUILD` for review, then builds and installs it with `makepkg -si` (prompting for your sudo password as usual).

## Why it isn't automated

Running it unattended (systemd timer, passwordless sudo) would need a NOPASSWD rule for `pacman -U`, which runs the package's install scriptlets as root and so amounts to full root access.
