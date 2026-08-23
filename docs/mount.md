[← Back to README](../README.md)

# `scripts/mount.sh`

An interactive script that helps you add a storage device to `/etc/fstab` and mount it persistently.

> [!NOTE]
> Run `mount.sh` as your normal user, not with `sudo`. It calls `sudo` itself for the individual steps that need root (creating the mount point, backing up and editing `/etc/fstab`, reloading systemd, mounting), so the mount point ends up owned by you instead of root.

## Usage

If you have a new storage device, run this to mount it:

```bash
./scripts/mount.sh
```

## What it does

1. **Show connected storage devices** — displays `lsblk` output with name, size, type, label, mount point, filesystem type, and UUID.
2. **Prompt for device and mount point** — asks for the device name (e.g., `sda1`) and an absolute mount path (e.g., `/mnt/data`).
3. **Create the mount point** — makes the directory if it doesn't exist and sets ownership to your user.
4. **Retrieve UUID and filesystem type** — looks up the device's UUID and filesystem type via `lsblk`.
5. **Add the fstab entry** — if an entry for that UUID doesn't already exist, backs up the current fstab to `/etc/fstab.bak` and appends `UUID=<uuid> <mount_point> <fstype> defaults 0 2`. Running the script again for the same device skips this step instead of adding a duplicate line.
6. **Reload systemd daemon** — runs `systemctl daemon-reload`.
7. **Mount everything** — runs `mount -a` to activate the new entry, warning (rather than failing silently) if it reports errors.
