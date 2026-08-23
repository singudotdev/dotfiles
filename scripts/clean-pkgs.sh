#!/bin/bash
set -euo pipefail

# Clears the pacman and Flatpak caches, then removes orphaned packages.
# Run manually after an upgrade to reclaim disk space.

echo "=== Starting Fully Automated Package Cleanup ==="

CACHE_DIR="/var/cache/pacman/pkg"
echo "Ensuring cache directory exists..."
if [ ! -d "$CACHE_DIR" ]; then
    echo "Cache directory missing. Recreating..."
    sudo mkdir -p "$CACHE_DIR"
    sudo chmod 755 "$CACHE_DIR"
    sudo chown root:root "$CACHE_DIR"
fi

echo "Cleaning Flatpak..."
flatpak uninstall --unused --assumeyes 2>/dev/null || echo "Nothing unused to uninstall."

echo "Removing stuck 'download-*' entries..."
# -mindepth 1 ensures we never delete the cache directory itself.
sudo find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -name "download-*" -exec rm -rf {} + 2>/dev/null || true

echo "Cleaning Pacman cache..."
# Retry non-interactively in case --noconfirm didn't suppress a prompt.
if ! sudo pacman -Sc --noconfirm; then
    echo "Standard clean failed or prompted. Trying force pipe..."
    echo "y" | sudo pacman -Sc
fi

echo "Checking for orphaned packages..."
ORPHANS=$(pacman -Qtdq)

if [ -z "$ORPHANS" ]; then
    echo "No orphaned packages found."
else
    echo "Removing orphans: $ORPHANS"
    # Retry non-interactively in case --noconfirm didn't suppress a prompt.
    if ! sudo pacman -Rns --noconfirm $ORPHANS; then
        echo "Orphan removal failed or prompted. Trying force pipe..."
        echo "y" | sudo pacman -Rns $ORPHANS
    fi
fi

echo "=== Cleanup Complete ==="
echo "Cache status:"
ls -ld "$CACHE_DIR"
du -sh "$CACHE_DIR" 2>/dev/null || echo "Directory is empty or inaccessible."
