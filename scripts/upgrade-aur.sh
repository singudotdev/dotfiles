#!/bin/bash
set -euo pipefail

# Checks the AUR for newer releases of the packages below and rebuilds any that are outdated.
# Run manually whenever you want to check for updates.

PACKAGES=(
    brave-origin-bin
    voltius-bin
)

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }

# makepkg refuses to run as root, so bail early with a clear message.
if [[ $EUID -eq 0 ]]; then
    fail "Do not run this script as root. Run as your normal user."
fi

command -v pacman &>/dev/null || fail "This script is intended for Arch Linux only."
command -v jq &>/dev/null || fail "jq is required (pacman -S jq)."

update_package() {
    local pkg="$1"
    local build_dir="/tmp/${pkg}"

    local installed_ver
    installed_ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)"
    if [ -z "$installed_ver" ]; then
        warn "$pkg is not installed, skipping"
        return
    fi

    local aur_ver
    aur_ver="$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?arg[]=${pkg}" | jq -r '.results[0].Version')"
    if [ -z "$aur_ver" ] || [ "$aur_ver" = "null" ]; then
        warn "Could not fetch version info for $pkg from the AUR, skipping"
        return
    fi

    log "$pkg — installed: $installed_ver  |  AUR: $aur_ver"

    if [ "$installed_ver" = "$aur_ver" ]; then
        ok "$pkg is already up to date."
        return
    fi

    log "Update available, rebuilding $pkg..."
    rm -rf "$build_dir"
    git clone "https://aur.archlinux.org/${pkg}.git" "$build_dir"
    cd "$build_dir"

    echo ""
    log "Please review the PKGBUILD below:"
    echo "----------------------------------------"
    bat PKGBUILD
    echo "----------------------------------------"
    echo ""
    read -rp "Proceed with build and install of $pkg? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn "Skipped $pkg"
        cd ~
        rm -rf "$build_dir"
        return
    fi

    makepkg -si --noconfirm --needed
    cd ~
    rm -rf "$build_dir"
    ok "$pkg updated to $aur_ver"
}

for pkg in "${PACKAGES[@]}"; do
    update_package "$pkg"
done

ok "AUR packages processed"
