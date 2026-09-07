[← Back to README](../README.md)

# `scripts/mount-disk.sh`

An interactive script that helps you add a storage device to `/etc/fstab`, mount it persistently, and optionally symlink any of its folders that match common home directory names (`Pictures`, `Projects`, `.config`, `.ssh`, etc.) into `$HOME`.

> [!NOTE]
> Run `mount-disk.sh` as your normal user, not with `sudo`. It calls `sudo` itself for the individual steps that need root (creating the mount point, backing up and editing `/etc/fstab`, reloading systemd, mounting), so the mount point ends up owned by you instead of root.

## Usage

If you have a new storage device, run this to mount it:

```bash
./scripts/mount-disk.sh
```

## What it does

1. **Show connected storage devices** — displays `lsblk` output with name, size, type, label, mount point, filesystem type, and UUID.
2. **Prompt for device and mount point** — asks for the device name (e.g., `sda1`) and an absolute mount path (e.g., `/mnt/data`).
3. **Create the mount point** — makes the directory if it doesn't exist and sets ownership to your user.
4. **Retrieve UUID and filesystem type** — looks up the device's UUID and filesystem type via `lsblk`.
5. **Add the fstab entry** — if an entry for that UUID doesn't already exist, backs up the current fstab to `/etc/fstab.bak` and appends `UUID=<uuid> <mount_point> <fstype> defaults 0 2`. Running the script again for the same device skips this step instead of adding a duplicate line.
6. **Reload systemd daemon** — runs `systemctl daemon-reload`.
7. **Mount everything** — runs `mount -a` to activate the new entry, warning (rather than failing silently) if it reports errors.
8. **Offer to symlink matching home folders** — checks the disk's top level for folders matching a known list (`Documents`, `Downloads`, `Pictures`, `Videos`, `Music`, `Desktop`, `Public`, `Templates`, `Projects`, `.config`, `.ssh`), and for each one found, asks whether to symlink `~/<name>` to it. What happens next depends on what's currently at `~/<name>`:

    | Current state of `~/<name>` | Result |
    | --- | --- |
    | Already a symlink pointing at this same disk folder | Skipped, nothing asked. |
    | Doesn't exist | Symlink created directly. |
    | Exists as an empty directory | The empty directory is removed, then symlinked. |
    | Exists with content in it | Asks whether to back it up first. **Yes** → renamed to `~/<name>.bak.<timestamp>`, then symlinked. **No** → deleted outright, then symlinked — so declining the backup doesn't leave anything behind for you to clean up later. |

    `.ssh` specifically also gets an extra warning before linking: ssh requires strict permissions (`700`/`600`), which non-Linux-native filesystems (exFAT/NTFS) can't represent correctly.

> [!NOTE]
> The backup question only comes up for the last case above — a folder that already has real content in it. Linking an empty or missing folder (the common case for a first-time setup) never asks about backups at all.
