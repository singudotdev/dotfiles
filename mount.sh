#!/bin/bash
set -euo pipefail

# This script adds a storage device to /etc/fstab and creates symlinks for common directories in the user's home directory.
# It requires root privileges to modify /etc/fstab and create mount points.
echo "=== Storage Device Setup Script ==="

# Ask for executing user confirmation
read -p "This script will modify /etc/fstab and create symlinks in your home directory. Do you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation cancelled by user."
    exit 1
fi

# Get storage devices info
lsblk -o NAME,SIZE,TYPE,LABEL,MOUNTPOINT,FSTYPE,UUID

# Prompt user for the device to add in fstab
read -p "Enter the device name (e.g., sda1) to add to /etc/fstab: " device_name

# Prompt user for the mount point in absolute path format
read -p "Enter the mount point (absolute path, e.g., /mnt/data): " mount_point

# Create the mount point directory if it doesn't exist for the user who executed the script
if [ ! -d "$mount_point" ]; then
    sudo mkdir -p "$mount_point"
    echo "Created mount point directory: $mount_point"
    # Set ownership of the mount point to the user who executed the script
    sudo chown "$(whoami):$(whoami)" "$mount_point"
fi

# Get the UUID of the device
uuid=$(lsblk -no UUID "/dev/$device_name" 2>/dev/null || true)

# Check if UUID was found
if [ -z "$uuid" ]; then
    echo "Error: Could not find UUID for device /dev/$device_name. Please check the device name and try again."
    exit 1
fi

# Determine the filesystem type of the device
fstype=$(lsblk -no FSTYPE "/dev/$device_name" 2>/dev/null || true)

# Check if filesystem type was found
if [ -z "$fstype" ]; then
    echo "Error: Could not determine filesystem type for device /dev/$device_name. Please check the device name and try again."
    exit 1
fi

# Add the new entry to /etc/fstab, unless it's already there
if grep -qF "UUID=$uuid" /etc/fstab; then
    echo "An entry for UUID=$uuid already exists in /etc/fstab, skipping."
else
    sudo cp /etc/fstab /etc/fstab.bak
    echo "Backup of /etc/fstab created at /etc/fstab.bak"

    echo "UUID=$uuid $mount_point $fstype defaults 0 2" | sudo tee -a /etc/fstab > /dev/null
    echo "Added entry to /etc/fstab: UUID=$uuid $mount_point $fstype defaults 0 2"
fi

# Reload the systemd daemon to recognize the new fstab entry
sudo systemctl daemon-reload
echo "Reloaded systemd daemon"

# Mount the new entry
if sudo mount -a; then
    echo "Mounted all entries in /etc/fstab"
else
    echo "Warning: mount -a reported errors, check the output above." >&2
fi
