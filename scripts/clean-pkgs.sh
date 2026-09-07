#!/bin/bash
set -euo pipefail

# Clears the pacman and Flatpak caches, then removes orphaned packages.
# Run manually after an upgrade to reclaim disk space.

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }

log "=== Starting Fully Automated Package Cleanup ==="

CACHE_DIR="/var/cache/pacman/pkg"
log "Ensuring cache directory exists..."
if [ ! -d "$CACHE_DIR" ]; then
    log "Cache directory missing. Recreating..."
    sudo mkdir -p "$CACHE_DIR"
    sudo chmod 755 "$CACHE_DIR"
    sudo chown root:root "$CACHE_DIR"
fi

log "Cleaning Flatpak..."
flatpak uninstall --unused --assumeyes 2>/dev/null || log "Nothing unused to uninstall."

log "Removing stuck 'download-*' entries..."
# -mindepth 1 ensures we never delete the cache directory itself.
sudo find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d -name "download-*" -exec rm -rf {} + 2>/dev/null || true

log "Cleaning Pacman cache..."
# Retry non-interactively in case --noconfirm didn't suppress a prompt.
if ! sudo pacman -Sc --noconfirm; then
    warn "Standard clean failed or prompted. Trying force pipe..."
    echo "y" | sudo pacman -Sc
fi

log "Checking for orphaned packages..."
ORPHANS=$(pacman -Qtdq)

if [ -z "$ORPHANS" ]; then
    log "No orphaned packages found."
else
    log "Removing orphans: $ORPHANS"
    # Retry non-interactively in case --noconfirm didn't suppress a prompt.
    if ! sudo pacman -Rns --noconfirm $ORPHANS; then
        warn "Orphan removal failed or prompted. Trying force pipe..."
        echo "y" | sudo pacman -Rns $ORPHANS
    fi
fi

ok "=== Cleanup Complete ==="
log "Cache status:"
ls -ld "$CACHE_DIR"
du -sh "$CACHE_DIR" 2>/dev/null || warn "Directory is empty or inaccessible."
