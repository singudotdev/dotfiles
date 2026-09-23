#!/bin/bash
set -euo pipefail

# Adds a storage device to /etc/fstab and mounts it, prompting interactively
# for the device name and mount point. Run manually when you add new storage.
#
# After mounting, also offers to symlink any top-level folder on the disk
# that matches a common home directory name (Pictures, Projects, .config,
# .ssh, etc.) to the corresponding path under $HOME.

# Folder names on the disk that get offered as a home symlink if found.
HOME_LINK_CANDIDATES=(
    Documents
    Downloads
    Pictures
    Videos
    Music
    Desktop
    Public
    Templates
    Projects
    .config
    .ssh
)

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }

log "=== Storage Device Setup Script ==="

read -p "This script will modify /etc/fstab and create a mount point directory. Do you want to continue? (y/n): " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { log "Cancelled."; exit 0; }

lsblk -o NAME,SIZE,TYPE,LABEL,MOUNTPOINT,FSTYPE,UUID

read -p "Enter the device name (e.g., sda1) to add to /etc/fstab: " device_name
read -p "Enter the mount point (absolute path, e.g., /mnt/data): " mount_point

if [ ! -d "$mount_point" ]; then
    sudo mkdir -p "$mount_point"
    log "Created mount point directory: $mount_point"
    sudo chown "$(whoami):$(whoami)" "$mount_point"
fi

uuid=$(lsblk -no UUID "/dev/$device_name" 2>/dev/null || true)
if [ -z "$uuid" ]; then
    fail "Could not find UUID for device /dev/$device_name. Please check the device name and try again."
fi

fstype=$(lsblk -no FSTYPE "/dev/$device_name" 2>/dev/null || true)
if [ -z "$fstype" ]; then
    fail "Could not determine filesystem type for device /dev/$device_name. Please check the device name and try again."
fi

# Avoid appending a duplicate line if this device is already in fstab.
if grep -qF "UUID=$uuid" /etc/fstab; then
    log "An entry for UUID=$uuid already exists in /etc/fstab, skipping."
else
    sudo cp /etc/fstab /etc/fstab.bak
    log "Backup of /etc/fstab created at /etc/fstab.bak"

    echo "UUID=$uuid $mount_point $fstype defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    log "Added entry to /etc/fstab: UUID=$uuid $mount_point $fstype defaults 0 2"
fi

sudo systemctl daemon-reload
log "Reloaded systemd daemon"

if sudo mount -a; then
    ok "Mounted all entries in /etc/fstab"
else
    warn "mount -a reported errors, check the output above."
fi

# ============================================================
# Offer to symlink matching folders on the disk into $HOME
# ============================================================
log ""
log "Checking $mount_point for folders matching common home directories..."

for name in "${HOME_LINK_CANDIDATES[@]}"; do
    disk_path="$mount_point/$name"
    home_path="$HOME/$name"

    [ -d "$disk_path" ] || continue

    if [ -L "$home_path" ] && [ "$(readlink -f "$home_path")" = "$(readlink -f "$disk_path")" ]; then
        log "$home_path is already symlinked to $disk_path, skipping"
        continue
    fi

    read -rp "Found '$name' on the disk. Symlink $home_path -> $disk_path? (y/n): " link_confirm
    [[ "$link_confirm" =~ ^[yY]$ ]] || { log "Skipped $name"; continue; }

    if [ "$name" = ".ssh" ]; then
        warn "ssh enforces strict permissions (700/600). If $mount_point isn't a Linux-native filesystem (ext4/btrfs/xfs), ssh may refuse to use keys through this symlink."
    fi

    if [ -e "$home_path" ] || [ -L "$home_path" ]; then
        if [ -d "$home_path" ] && [ ! -L "$home_path" ] && [ -z "$(ls -A "$home_path" 2>/dev/null)" ]; then
            log "$home_path exists but is empty, removing it"
            rmdir "$home_path"
        else
            backup_path="${home_path}.bak.$(date +%Y%m%d_%H%M%S)"
            warn "$home_path already exists and has content — it will be replaced by the symlink."
            read -rp "Back it up to $backup_path first? (y/n): " backup_confirm
            if [[ "$backup_confirm" =~ ^[yY]$ ]]; then
                mv "$home_path" "$backup_path"
                ok "Backed up existing $home_path to $backup_path"
            else
                rm -rf "$home_path"
                ok "Removed existing $home_path (no backup requested)"
            fi
        fi
    fi

    mkdir -p "$(dirname "$home_path")"
    ln -s "$disk_path" "$home_path"
    ok "Linked $home_path -> $disk_path"
done
