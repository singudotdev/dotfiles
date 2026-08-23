#!/bin/bash
set -euo pipefail

# Adds a storage device to /etc/fstab and mounts it, prompting interactively
# for the device name and mount point. Run manually when you add new storage.

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
