#!/bin/bash
set -euo pipefail

# ============================================================
# Arch Linux Setup Script
# ============================================================
# Run once, right after a fresh archinstall. Not meant to be re-run.

echo "=== Arch Linux Setup Script ==="

# ============================================================
# Configuration - edit these to change what gets installed/linked
# ============================================================

PACKAGES=(
    git man-db zed vim ghostty starship fish bottom eza bat fastfetch jq yq
    flatpak flatseal cuda lib32-nvidia-utils steam podman
    gnome-keyring proton-vpn-gtk-app
    ttf-hack-nerd ttf-input-nerd
)

# Flatpak applications (Flathub app IDs)
FLATPAKS=(
    com.github.tchx84.Flatseal
    im.riot.Riot
    org.kde.kalk
    org.telegram.desktop
    com.vysp3r.ProtonPlus
)

# AUR packages to build and install with makepkg (no AUR helper required)
AUR_PACKAGES=(
    brave-origin-bin
)

# Dotfiles to symlink, one per line: "path in this repo:target under $HOME"
DOTFILE_LINKS=(
    "DankMaterialShell:.config/DankMaterialShell"
    "fish:.config/fish"
    "ghostty:.config/ghostty"
    "niri:.config/niri"
    "zed:.config/zed"
    "starship/starship.toml:.config/starship.toml"
    "fetch:.config/fetch"
    "scripts/upgrade-aur.sh:.local/bin/upgrade-aur"
    "scripts/clean-pkgs.sh:.local/bin/clean-pkgs"
    "scripts/fix-zed-transparency.sh:.local/bin/fix-zed-transparency"
)

GIT_EMAIL="contact@singu.dev"
GIT_NAME="singudotdev"

SUDO_TIMESTAMP_TIMEOUT=5   # minutes sudo remembers your password

OLLAMA_NUM_CTX=16384
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KEEP_ALIVE=10m

MODELS=(
    "qwen2.5-coder:7b-base"   # Autocomplete / inline predictions
    "qwen2.5-coder:7b"        # Fast snippets / chat
)

# ============================================================
# Pre-flight checks
# ============================================================
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Do not run this script as root. Run as your normal user."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    echo "ERROR: This script is intended for Arch Linux only."
    exit 1
fi

# archinstall is expected to have already set these up.
missing=()
for pkg in niri polkit; do
    pacman -Qi "$pkg" &>/dev/null || missing+=("package '$pkg' is not installed")
done

nvidia_found="no"
for drv in nvidia nvidia-lts nvidia-open nvidia-open-lts nvidia-dkms nvidia-open-dkms; do
    pacman -Qi "$drv" &>/dev/null && nvidia_found="yes"
done
[ "$nvidia_found" = "yes" ] || missing+=("no nvidia driver package installed")

pacman-conf --repo-list 2>/dev/null | grep -qx multilib \
    || missing+=("multilib repo is not enabled in /etc/pacman.conf")

if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: Missing prerequisites (expected from archinstall):" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    exit 1
fi

read -rp "This script will update the system, install packages, configure dotfiles, and set up services. Continue? (y/n): " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { echo "Cancelled."; exit 0; }

# ============================================================
# Helpers
# ============================================================
log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }
step() { echo ""; log "── $1 ──"; }

USER_HOME="$HOME"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# 1. System update & package install
# ============================================================
step "Updating system and installing packages"
sudo pacman -Syu --noconfirm --needed "${PACKAGES[@]}" || fail "Package installation failed"
ok "Packages installed"

# ============================================================
# 2. Sudoers configuration
# ============================================================
step "Configuring sudo access"

CURRENT_USER="$(whoami)"

sudo tee /etc/sudoers.d/00_"$CURRENT_USER" > /dev/null <<EOF
$CURRENT_USER ALL=(ALL) ALL
EOF
sudo chmod 440 /etc/sudoers.d/00_"$CURRENT_USER"

sudo tee /etc/sudoers.d/10_defaults > /dev/null <<EOF
Defaults timestamp_timeout=$SUDO_TIMESTAMP_TIMEOUT
Defaults log_input, log_output
Defaults logfile="/var/log/sudo.log"
EOF
sudo chmod 440 /etc/sudoers.d/10_defaults

# Validate before trusting it - a broken sudoers file can lock you out of sudo.
sudo visudo -c &>/dev/null || fail "Sudoers config is invalid, check /etc/sudoers.d/"
ok "Sudo configured"

# ============================================================
# 3. Flatpaks
# ============================================================
step "Installing Flatpak applications"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

for fp in "${FLATPAKS[@]}"; do
    if flatpak list --columns=application 2>/dev/null | grep -Fxq "$fp"; then
        log "$fp already installed, skipping"
    else
        flatpak install -y flathub "$fp" || warn "Failed to install $fp"
    fi
done
ok "Flatpaks processed"

# ============================================================
# 4. AUR packages
# ============================================================
step "Installing AUR packages"
for pkg in "${AUR_PACKAGES[@]}"; do
    log "Building $pkg..."
    build_dir="/tmp/${pkg}"
    rm -rf "$build_dir"
    git clone "https://aur.archlinux.org/${pkg}.git" "$build_dir" || { warn "Failed to clone $pkg from AUR"; continue; }
    (cd "$build_dir" && makepkg -si --noconfirm --needed) || warn "Failed to install $pkg"
    rm -rf "$build_dir"
done
ok "AUR packages processed"

# ============================================================
# 5. DankMaterialShell
# ============================================================
step "Installing DankMaterialShell"
curl -fsSL https://install.danklinux.com | sh || warn "DankMaterialShell install failed"

# ============================================================
# 6. Dotfile symlinks
# ============================================================
step "Linking dotfiles"

link_replace() {
    local source="$1" target="$2"

    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "${target}.bak.$(date +%Y%m%d_%H%M%S)"
        log "Backed up existing $target"
    fi

    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    ok "Linked $target -> $source"
}

for entry in "${DOTFILE_LINKS[@]}"; do
    IFS=':' read -r source_path target_path <<< "$entry"
    link_replace "${DOTFILES_DIR}/${source_path}" "${USER_HOME}/${target_path}"
done

# ============================================================
# 7. Bluetooth
# ============================================================
step "Disabling Bluetooth auto-enable"
if [ -f /etc/bluetooth/main.conf ]; then
    sudo sed -i 's/^#AutoEnable=true/AutoEnable=false/' /etc/bluetooth/main.conf
    ok "Bluetooth configured"
else
    warn "Bluetooth not installed, skipping"
fi

# ============================================================
# 8. Git config
# ============================================================
step "Configuring Git"
git config --global user.email "$GIT_EMAIL"
git config --global user.name  "$GIT_NAME"
ok "Git configured"

# ============================================================
# 9. Claude Code
# ============================================================
step "Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | sh || warn "Claude Code install failed"

# ============================================================
# 10. Ollama
# ============================================================
step "Setting up Ollama"
curl -fsSL https://ollama.com/install.sh | sh || fail "Ollama install failed"

sudo mkdir -p /var/lib/ollama
sudo chown -R ollama:ollama /var/lib/ollama
sudo chmod 750 /var/lib/ollama

sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_NUM_CTX=${OLLAMA_NUM_CTX}"
Environment="OLLAMA_FLASH_ATTENTION=${OLLAMA_FLASH_ATTENTION}"
Environment="OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE}"
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ollama || warn "Ollama service failed to start"
ok "Ollama configured"

step "Pulling Ollama models"
for model in "${MODELS[@]}"; do
    log "Pulling $model..."
    ollama pull "$model" || warn "Failed to pull $model"
done
ok "Model pulls complete"

# ============================================================
# Done
# ============================================================
echo ""
ok "Setup complete!"
echo ""
warn "Rebooting in 5 seconds... (Ctrl+C to cancel)"
sleep 5
sudo reboot
