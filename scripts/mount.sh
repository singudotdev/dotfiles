#!/bin/bash
set -euo pipefail

# Adds a storage device to /etc/fstab and mounts it, prompting interactively
# for the device name and mount point. Run manually when you add new storage.

echo "=== Storage Device Setup Script ==="

read -p "This script will modify /etc/fstab and create a mount point directory. Do you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation cancelled by user."
    exit 1
fi

lsblk -o NAME,SIZE,TYPE,LABEL,MOUNTPOINT,FSTYPE,UUID

read -p "Enter the device name (e.g., sda1) to add to /etc/fstab: " device_name
read -p "Enter the mount point (absolute path, e.g., /mnt/data): " mount_point

if [ ! -d "$mount_point" ]; then
    sudo mkdir -p "$mount_point"
    echo "Created mount point directory: $mount_point"
    sudo chown "$(whoami):$(whoami)" "$mount_point"
fi

uuid=$(lsblk -no UUID "/dev/$device_name" 2>/dev/null || true)
if [ -z "$uuid" ]; then
    echo "Error: Could not find UUID for device /dev/$device_name. Please check the device name and try again."
    exit 1
fi

fstype=$(lsblk -no FSTYPE "/dev/$device_name" 2>/dev/null || true)
if [ -z "$fstype" ]; then
    echo "Error: Could not determine filesystem type for device /dev/$device_name. Please check the device name and try again."
    exit 1
fi

# Avoid appending a duplicate line if this device is already in fstab.
if grep -qF "UUID=$uuid" /etc/fstab; then
    echo "An entry for UUID=$uuid already exists in /etc/fstab, skipping."
else
    sudo cp /etc/fstab /etc/fstab.bak
    echo "Backup of /etc/fstab created at /etc/fstab.bak"

    echo "UUID=$uuid $mount_point $fstype defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    echo "Added entry to /etc/fstab: UUID=$uuid $mount_point $fstype defaults 0 2"
fi

sudo systemctl daemon-reload
echo "Reloaded systemd daemon"

if sudo mount -a; then
    echo "Mounted all entries in /etc/fstab"
else
    echo "Warning: mount -a reported errors, check the output above." >&2
fi
