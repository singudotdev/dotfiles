[← Back to README](../README.md)

# `scripts/btrfs-optimize.sh`

Applies the btrfs tuning used on this workstation to whatever btrfs filesystem currently hosts `/`.

> [!NOTE]
> Run `btrfs-optimize.sh` as your normal user, not with `sudo`. It calls `sudo` itself for the individual steps that need root, so the Steam subvolume and mount point end up owned by you instead of root.

> [!WARNING]
> This edits `/etc/fstab`, remounts live filesystems, moves `~/.local/share/Steam` into a new subvolume (if there's existing data), and — if Limine is installed — **fully redeploys Limine** (new EFI binary, new UEFI boot entry, rebuilt `limine.conf`) and rebuilds the initramfs. It's safe to re-run — every phase detects whether it already applied and skips — but review it before running on a system you care about, and reboot to confirm the boot menu looks right (your original boot path is preserved as an `EFI fallback` entry either way).

## Usage

Run once after a fresh install (or anytime to bring an existing system in line):

```bash
./scripts/btrfs-optimize.sh
```

It works on whatever UUID/device currently backs `/` — nothing is hardcoded to a specific machine.

## What it does

1. **fstab rewrite** — for every fstab line on root's UUID: drops `nodatacow`/`nodatasum`, converts `relatime` to `noatime`, adds `compress=zstd:1` (skipped if a `compress=` option is already present). Backs up `/etc/fstab` first, then runs `systemctl daemon-reload` so systemd picks up the new options immediately instead of nagging about a stale fstab on the next mount.
2. **Live remount** — applies `noatime,compress=zstd:1,datacow` to every currently-mounted btrfs subvolume on that UUID, without touching other options (like `ssd`/`discard`/`space_cache`) the installer already set.
3. **I/O scheduler** — sets `none` for the underlying NVMe device (multi-queue hardware doesn't need software rescheduling), persisted via a udev rule. Skipped with a warning on non-NVMe disks.
4. **Rewrites existing data** — `btrfs filesystem defragment -r -czstd` on every mount, so already-written files actually get checksummed and compressed instead of only new writes. Skipped automatically if snapshots already exist (defragmenting after snapshots exist breaks shared extents and bloats space).
5. **Periodic scrub** — enables `btrfs-scrub@-.timer` if available (btrfsmaintenance), otherwise creates a simple custom monthly scrub unit. Scrub is what actually uses the checksums from step 4 to catch and repair corruption.
6. **Disables snapper's timeline snapshots** — sets `TIMELINE_CREATE="no"` and `NUMBER_LIMIT="10"` in every `/etc/snapper/configs/*`, and disables `snapper-timeline.timer`, if snapper is installed. Continuous snapshots are replaced by the pre/post pair the [`supgrade`](./fish-functions.md) fish function creates around each upgrade instead; capping `NUMBER_LIMIT` at 10 keeps roughly the last 5 upgrade cycles (2 snapshots each) instead of piling up indefinitely.
7. **Steam subvolume** — creates a `@steam` subvolume and mounts it at `~/.local/share/Steam`, adding the fstab entry (again followed by `systemctl daemon-reload`). If Steam data already exists there, it's copied over with `rsync` first and the original is kept at `~/.local/share/Steam.old` for you to verify and remove manually. This keeps game installs/updates out of home snapshots (snapshots don't recurse into a nested subvolume). Skipped if Steam is currently running.
8. **Limine boot-menu snapshot integration** — if Limine is installed and a snapper `root` config exists, builds and installs [`limine-snapper-sync`](https://gitlab.com/Zesko/limine-snapper-sync) from the AUR, plus the matching `limine-mkinitcpio-hook`/`sd-btrfs-overlayfs` initramfs hook (needed so a booted read-only snapshot can still be written to at boot — e.g. by a display manager). **Installing `limine-mkinitcpio-hook` fully redeploys Limine** using [`limine-entry-tool`](https://gitlab.com/Zesko/limine-entry-tool)'s auto-generated config — a new EFI binary (`EFI/limine/limine_x64.efi`), a new UEFI boot entry placed first in the boot order, and a new `limine.conf` built from scratch (with your original UKI/entry preserved as a fallback item inside it). This is a bigger change than a config tweak, but it's what actually makes snapshots show up as boot entries — a plain "add a marker line" edit isn't how the current tooling works.
    - The script finds wherever the real `limine.conf` ends up (an archinstall UKI setup typically has it nested at `<boot>/EFI/BOOT/limine.conf`, not directly under the boot mountpoint) and pins `ESP_PATH` to that directory in `/etc/limine-snapper-sync.conf`.
    - **If an older `limine.conf` still exists elsewhere** (exactly the archinstall UKI case), the script renames it to `limine.conf.disabled`. This matters because Limine's own boot-time config search can silently prefer a stale file over the new one regardless of which EFI binary launched — confirmed live: without this cleanup, the boot menu showed only the old single entry with none of the new snapshot/fallback entries, even though the new config was correctly written. Nothing is deleted — the original file survives as `.disabled` and can be restored by renaming it back.
    - Sets `EXCLUDE_SNAPSHOT_TYPES="post"` (only `pre` snapshots are meaningful rollback points), enables `limine-snapper-sync.service`, and runs an initial sync.
    - Skipped entirely if Limine isn't your bootloader. **Reboot afterward and check the boot menu** — you should see your OS entry, a nested `Snapshots` submenu, and an `EFI fallback` entry that chainloads the original boot path if anything looks wrong.

## Why these choices

- No VMs or databases run on this machine, so there's no workload that benefits from `nodatacow` — dropping it filesystem-wide restores checksumming (real corruption detection) and lets snapshots mean something.
- `compress=zstd:1` trades negligible CPU for less I/O — a net win on NVMe, and free disk space.
- Continuous timeline snapshots aren't useful here; the moments worth protecting are upgrades, which `supgrade` already snapshots explicitly.
- A capped, boot-visible snapshot history (steps 6 and 8 together) means a bad upgrade is recoverable straight from the boot menu, without needing a live USB — while still bounded so it doesn't clutter that menu or eat disk space indefinitely.
