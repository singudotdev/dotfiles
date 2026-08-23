#!/bin/bash

set -e # Exit on error

echo "=== Starting Fully Automated Package Cleanup ==="

# --- 1. Ensure Cache Directory Exists ---
CACHE_DIR="/var/cache/pacman/pkg"
echo "Ensuring cache directory exists..."
if [ ! -d "$CACHE_DIR" ]; then
    echo "Cache directory missing. Recreating..."
    sudo mkdir -p "$CACHE_DIR"
    sudo chmod 755 "$CACHE_DIR"
    sudo chown root:root "$CACHE_DIR"
fi

# --- 2. Clean Flatpak ---
echo "Cleaning Flatpak..."
flatpak uninstall --unused --assumeyes 2>/dev/null || echo "Nothing unused to uninstall."

# --- 3. Fix Corrupted 'download-*' Entries ---
echo "Removing stuck 'download-*' entries..."
# We use -mindepth 1 to ensure we never delete the parent directory itself
sudo find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -name "download-*" -exec rm -rf {} + 2>/dev/null || true

# --- 4. Clean Pacman Cache (Force Non-Interactive) ---
echo "Cleaning Pacman cache..."

# Method 1: Use --noconfirm explicitly
# If this still prompts, we pipe 'yes' as a backup
if ! sudo pacman -Sc --noconfirm; then
    echo "Standard clean failed or prompted. Trying force pipe..."
    echo "y" | sudo pacman -Sc
fi

# --- 5. Remove Orphaned Packages ---
echo "Checking for orphaned packages..."
ORPHANS=$(pacman -Qtdq)

if [ -z "$ORPHANS" ]; then
    echo "No orphaned packages found."
else
    echo "Removing orphans: $ORPHANS"
    # Use --noconfirm here too
    if ! sudo pacman -Rns --noconfirm $ORPHANS; then
        echo "Orphan removal failed or prompted. Trying force pipe..."
        echo "y" | sudo pacman -Rns $ORPHANS
    fi
fi

# --- 6. Clean Paru AUR Builds ---
echo "Cleaning Paru AUR build cache..."
# paru -Scc --noconfirm
if ! paru -Scc --noconfirm; then
    echo "Paru clean failed or prompted. Trying force pipe..."
    echo "y" | paru -Scc
fi

# --- 7. Remove Unused Repositories (If applicable) ---
echo "Removing unused sync repositories..."
# This is often handled by the orphan removal, but if you have a specific command:
# echo "y" | sudo pacman -Rns --noconfirm $(pacman -Qtdq) 2>/dev/null || true

echo "=== Cleanup Complete ==="
echo "Cache status:"
ls -ld "$CACHE_DIR"
du -sh "$CACHE_DIR" 2>/dev/null || echo "Directory is empty or inaccessible."

