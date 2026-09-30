[← Back to README](../README.md)

# `scripts/btrfs-optimize.sh`

Applies the btrfs tuning used on this workstation to whatever btrfs filesystem currently hosts `/`.

> [!NOTE]
> Run `btrfs-optimize.sh` as your normal user, not with `sudo`. It calls `sudo` itself for the individual steps that need root, so the Steam subvolume and mount point end up owned by you instead of root.

> [!WARNING]
> This edits `/etc/fstab`, remounts live filesystems, moves `~/.local/share/Steam` into a new subvolume (if there's existing data), and — if GRUB is installed — adds a hook to `/etc/mkinitcpio.conf` and regenerates the initramfs and `grub.cfg`. It's safe to re-run — every phase detects whether it already applied and skips — but review it before running on a system you care about, and reboot to confirm the system boots cleanly with the new fstab and boot menu.

## Usage

Run once after a fresh install, or any time to bring an existing system in line. It works on whatever device backs `/`; nothing is machine-specific.

```bash
./scripts/btrfs-optimize.sh
```

## What it does

1. **fstab rewrite** — for every fstab line on root's UUID: drops `nodatacow`/`nodatasum`, converts `relatime` to `noatime`, adds `compress=zstd:1` (skipped if a `compress=` option is already present). Backs up `/etc/fstab` first, then runs `systemctl daemon-reload` so systemd picks up the new options immediately instead of nagging about a stale fstab on the next mount.

2. **Live remount** — applies `noatime,compress=zstd:1,datacow` to every currently-mounted btrfs subvolume on that UUID, without touching other options (like `ssd`/`discard`/`space_cache`) the installer already set.

3. **I/O scheduler** — sets `none` for the underlying NVMe device (multi-queue hardware doesn't need software rescheduling), persisted via a udev rule. Skipped with a warning on non-NVMe disks.

4. **Rewrites existing data** — `btrfs filesystem defragment -r -czstd` on every mount, so already-written files actually get checksummed and compressed instead of only new writes. Skipped automatically if snapshots already exist (defragmenting after snapshots exist breaks shared extents and bloats space).

5. **Periodic scrub** — enables `btrfs-scrub@-.timer` if available (btrfsmaintenance), otherwise creates a simple custom monthly scrub unit. Scrub is what actually uses the checksums from step 4 to catch and repair corruption.

6. **Disables snapper's timeline snapshots** — sets `TIMELINE_CREATE="no"` and `NUMBER_LIMIT="10"` in every `/etc/snapper/configs/*`, and disables `snapper-timeline.timer`, if snapper is installed. Continuous snapshots are replaced by the pre/post pair the [`supgrade`](./fish-functions.md) fish function creates around each upgrade instead; capping `NUMBER_LIMIT` at 10 keeps roughly the last 5 upgrade cycles (2 snapshots each) instead of piling up indefinitely.

7. **Steam subvolume** — creates a `@steam` subvolume and mounts it at `~/.local/share/Steam`, adding the fstab entry (again followed by `systemctl daemon-reload`). If Steam data already exists there, it's copied over with `rsync` first and the original is kept at `~/.local/share/Steam.old` for you to verify and remove manually. This keeps game installs/updates out of home snapshots (snapshots don't recurse into a nested subvolume). Skipped if Steam is currently running.

8. **GRUB boot-menu snapshot integration** — if GRUB is installed and a snapper `root` config exists, installs [`grub-btrfs`](https://github.com/Antynea/grub-btrfs) and `inotify-tools` from the official repos.
    - Appends the `grub-btrfs-overlayfs` hook to `HOOKS` in `/etc/mkinitcpio.conf` (backing it up first) and runs `mkinitcpio -P`, so a read-only snapshot stays writable at boot (e.g. for the display manager). Skipped with a warning if the initramfs is systemd-based, which that hook doesn't support.
    - Sets `GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=("post")` in `/etc/default/grub-btrfs/config` (only `pre` snapshots are meaningful rollback points).
    - Enables `grub-btrfsd.service`, which regenerates the snapshot submenu whenever snapper creates or deletes a snapshot, and runs `grub-mkconfig -o /boot/grub/grub.cfg` once to add it now.
    - Skipped entirely if GRUB isn't your bootloader. **Reboot afterward and check the boot menu** for an `Arch Linux snapshots` submenu.

    > [!NOTE]
    > With `/boot` on a separate partition (archinstall's default ESP layout), snapshots don't contain the kernel. After a kernel upgrade, booting an older snapshot runs the new kernel against the snapshot's old `/usr/lib/modules`, so some modules (e.g. `nvidia`) may not load. It still reaches a TTY, which is enough for `snapper rollback`.

## Why these choices

- No VMs or databases run on this machine, so there's no workload that benefits from `nodatacow` — dropping it filesystem-wide restores checksumming (real corruption detection) and lets snapshots mean something.

- `compress=zstd:1` trades negligible CPU for less I/O — a net win on NVMe, and free disk space.

- Continuous timeline snapshots aren't useful here; the moments worth protecting are upgrades, which `supgrade` already snapshots explicitly.

- A capped, boot-visible snapshot history (steps 6 and 8 together) means a bad upgrade is recoverable straight from the boot menu, without needing a live USB — while still bounded so it doesn't clutter that menu or eat disk space indefinitely.
