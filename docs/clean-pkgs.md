[← Back to README](../README.md)

# `scripts/clean-pkgs.sh`

Reclaims disk space after an upgrade by clearing the pacman/Flatpak caches and removing orphaned packages.

Symlinked to `~/.local/bin/clean-pkgs` by [`init.sh`](./init.md). [`supgrade`](./fish-functions.md#supgrade) runs it at the end of every upgrade.

## Usage

```bash
clean-pkgs
```

## What it does

1. **Recreate the pacman cache dir** — if `/var/cache/pacman/pkg` is missing, recreates it with the right ownership/permissions.

2. **Clean Flatpak** — `flatpak uninstall --unused` to drop runtimes nothing depends on anymore.

3. **Remove stuck partial downloads** — deletes any leftover `download-*` directories in the pacman cache.

4. **Clean the pacman cache** — `pacman -Sc` to drop cached versions of packages that are no longer installed.

5. **Remove orphaned packages** — uninstalls packages nothing depends on anymore (`pacman -Qtdq`), including any left behind by `upgrade-aur.sh`'s AUR rebuilds.
