[← Back to README](../README.md)

# `scripts/clean-pkgs.sh`

Reclaims disk space after an upgrade by clearing the pacman/Flatpak caches and removing orphaned packages.

> [!NOTE]
> `init.sh` symlinks the script to `~/.local/bin/clean-pkgs` (no `.sh`, so it behaves like a regular binary on `PATH`), so after setup it's callable from anywhere as `clean-pkgs`; the `supgrade` fish function (see [`fish/functions/supgrade.fish`](../fish/functions/supgrade.fish)) runs it automatically after `upgrade-aur` on every upgrade.

## Usage

Run this after an upgrade to clear caches and remove orphaned packages:

```bash
./scripts/clean-pkgs.sh
```

## What it does

1. **Recreate the pacman cache dir** — if `/var/cache/pacman/pkg` is missing, recreates it with the right ownership/permissions.
2. **Clean Flatpak** — `flatpak uninstall --unused` to drop runtimes nothing depends on anymore.
3. **Remove stuck partial downloads** — deletes any leftover `download-*` directories in the pacman cache.
4. **Clean the pacman cache** — `pacman -Sc` to drop cached versions of packages that are no longer installed.
5. **Remove orphaned packages** — uninstalls packages nothing depends on anymore (`pacman -Qtdq`), including any left behind by `upgrade-aur.sh`'s AUR rebuilds.
