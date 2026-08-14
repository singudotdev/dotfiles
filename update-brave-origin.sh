#!/bin/bash
set -euo pipefail

# Checks the AUR for a newer brave-origin-bin release and rebuilds it if found.
# Run manually whenever you want to check for updates.

PKG=brave-origin-bin
BUILD_DIR="/tmp/${PKG}"

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }

if [[ $EUID -eq 0 ]]; then
    fail "Do not run this script as root. Run as your normal user."
fi

command -v pacman &>/dev/null || fail "This script is intended for Arch Linux only."
command -v jq &>/dev/null || fail "jq is required (pacman -S jq)."

installed_ver="$(pacman -Q "$PKG" 2>/dev/null | awk '{print $2}' || true)"
[ -n "$installed_ver" ] || fail "$PKG is not installed. Run init.sh's Brave Origin step first."

aur_ver="$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?arg[]=${PKG}" | jq -r '.results[0].Version')"
[ -n "$aur_ver" ] && [ "$aur_ver" != "null" ] || fail "Could not fetch version info from the AUR."

log "Installed: $installed_ver  |  AUR: $aur_ver"

if [ "$installed_ver" = "$aur_ver" ]; then
    ok "$PKG is already up to date."
    exit 0
fi

log "Update available, rebuilding $PKG..."
rm -rf "$BUILD_DIR"
git clone https://aur.archlinux.org/${PKG}.git "$BUILD_DIR"
cd "$BUILD_DIR"
less PKGBUILD
makepkg -si --noconfirm --needed
cd ~
rm -rf "$BUILD_DIR"
ok "$PKG updated to $aur_ver"
