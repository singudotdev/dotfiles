#!/bin/bash
set -euo pipefail

# Applies the btrfs tuning used on this workstation to whatever btrfs filesystem
# currently hosts /: drops nodatacow/nodatasum, switches to noatime + zstd
# compression, sets the NVMe I/O scheduler to none, enables periodic scrub,
# turns off snapper's timeline (continuous) snapshots in favor of the
# pre/post pair `supgrade` takes, moves the Steam library into its own
# subvolume so game installs don't bloat home snapshots, and — if GRUB is
# the bootloader — sets up grub-btrfs so snapshots show up as boot entries
# you can roll back into directly from the boot menu.
#
# Safe to re-run: every phase detects whether it already applied and skips.
# Run manually after a fresh install (or anytime) — not part of init.sh,
# since it assumes a working btrfs root already set up by the installer.

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
fail() { echo -e "\033[1;31m[ERR]\033[0m   $*" >&2; exit 1; }
step() { echo ""; log "── $1 ──"; }

log "=== Btrfs Optimization Script ==="

if [[ $EUID -eq 0 ]]; then
    fail "Do not run this as root. Run as your normal user — it calls sudo itself."
fi

command -v btrfs &>/dev/null || fail "btrfs-progs not installed."
[[ "$(findmnt -no FSTYPE /)" == "btrfs" ]] || fail "/ is not btrfs, nothing to optimize."

ROOT_UUID="$(findmnt -no UUID /)"
ROOT_SRC="$(findmnt -no SOURCE / | sed 's/\[.*\]//')"
ROOT_DISK="$(lsblk -no pkname "$ROOT_SRC" 2>/dev/null || true)"
FSTAB="/etc/fstab"

[ -n "$ROOT_UUID" ] || fail "Could not determine root filesystem UUID."

log "Root btrfs filesystem: UUID=$ROOT_UUID on $ROOT_SRC"

read -rp "This will edit /etc/fstab, remount filesystems live, tune I/O scheduler, enable scrub, disable snapper timeline snapshots, move ~/.local/share/Steam into its own subvolume, and (if GRUB is installed) set up grub-btrfs, rebuilding the initramfs and grub.cfg. Continue? (y/n): " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { log "Cancelled."; exit 0; }

# ============================================================
# 1. fstab: drop nodatacow/nodatasum, noatime, compress=zstd:1
# ============================================================
step "Rewriting fstab entries for UUID=$ROOT_UUID"

sudo cp "$FSTAB" "${FSTAB}.bak.$(date +%Y%m%d%H%M%S)"
log "Backed up $FSTAB"

tmp_fstab="$(mktemp)"
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == \#* ]] || [[ "$line" != *"$ROOT_UUID"* ]] || [[ "$line" != *btrfs* ]]; then
        printf '%s\n' "$line" >> "$tmp_fstab"
        continue
    fi

    read -r f_spec f_target f_type f_opts f_dump f_pass <<< "$line"

    IFS=',' read -ra opts <<< "$f_opts"
    new_opts=()
    has_atime="no"
    has_compress="no"
    for o in "${opts[@]}"; do
        case "$o" in
            nodatacow|nodatasum) continue ;;
            relatime) new_opts+=("noatime"); has_atime="yes" ;;
            atime|noatime) new_opts+=("$o"); has_atime="yes" ;;
            compress*) new_opts+=("$o"); has_compress="yes" ;;
            *) new_opts+=("$o") ;;
        esac
    done
    [ "$has_atime" = "no" ] && new_opts+=("noatime")
    [ "$has_compress" = "no" ] && new_opts+=("compress=zstd:1")

    new_opts_str="$(IFS=,; echo "${new_opts[*]}")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$f_spec" "$f_target" "$f_type" "$new_opts_str" "$f_dump" "$f_pass" >> "$tmp_fstab"
done < "$FSTAB"
sudo cp "$tmp_fstab" "$FSTAB"
rm -f "$tmp_fstab"
sudo systemctl daemon-reload
ok "fstab updated"

# ============================================================
# 2. Apply live via remount (only the deltas — other options like
#    ssd/discard/space_cache set by the installer are left untouched)
# ============================================================
step "Remounting live btrfs mounts"
while read -r target; do
    log "remounting $target"
    sudo mount -o remount,noatime,compress=zstd:1,datacow "$target"
done < <(findmnt -rno TARGET,UUID -t btrfs | awk -v u="$ROOT_UUID" '$2==u{print $1}')
ok "Live remount complete"

# ============================================================
# 3. NVMe I/O scheduler -> none (multi-queue hardware doesn't need
#    the kernel re-scheduling it in software)
# ============================================================
step "I/O scheduler"
if [[ "$ROOT_DISK" == nvme* ]]; then
    echo none | sudo tee "/sys/block/$ROOT_DISK/queue/scheduler" >/dev/null
    sudo tee /etc/udev/rules.d/60-ioscheduler.rules >/dev/null <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
EOF
    ok "Scheduler set to none for $ROOT_DISK, persisted via udev rule"
else
    warn "$ROOT_DISK is not NVMe, leaving I/O scheduler untouched"
fi

# ============================================================
# 4. Rewrite existing data so it picks up checksums/compression
#    (only new writes get these from the mount option change alone)
# ============================================================
step "Rewriting existing data (checksums + compression)"
has_snapshots="no"
if command -v snapper &>/dev/null && [ -f /etc/snapper/configs/root ]; then
    sudo snapper -c root list 2>/dev/null | grep -qE '^\s*[0-9]+\s' && has_snapshots="yes"
fi

if [ "$has_snapshots" = "yes" ]; then
    warn "Snapshots already exist — skipping defragment (it would break shared extents and bloat snapshot space)"
else
    while read -r target; do
        log "defragmenting $target ..."
        sudo btrfs filesystem defragment -r -czstd "$target"
    done < <(findmnt -rno TARGET,UUID -t btrfs | awk -v u="$ROOT_UUID" '$2==u{print $1}')
    ok "Defragment complete"
fi

# ============================================================
# 5. Periodic scrub (uses checksums to catch/repair corruption)
# ============================================================
step "Periodic scrub"
if systemctl list-unit-files 'btrfs-scrub@*' 2>/dev/null | grep -q scrub; then
    sudo systemctl enable --now btrfs-scrub@-.timer
    ok "btrfs-scrub@-.timer enabled"
elif systemctl list-unit-files btrfs-scrub-root.timer 2>/dev/null | grep -q scrub; then
    log "Custom scrub timer already present, skipping"
else
    sudo tee /etc/systemd/system/btrfs-scrub-root.service >/dev/null <<'EOF'
[Unit]
Description=Btrfs scrub on /

[Service]
Type=oneshot
ExecStart=/usr/bin/btrfs scrub start -B /
EOF
    sudo tee /etc/systemd/system/btrfs-scrub-root.timer >/dev/null <<'EOF'
[Unit]
Description=Monthly btrfs scrub on /

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now btrfs-scrub-root.timer
    ok "Custom monthly scrub timer created and enabled"
fi

# ============================================================
# 6. Disable snapper's continuous timeline snapshots (rely on
#    the pre/post pair the `supgrade` fish function creates instead)
# ============================================================
step "Snapper timeline snapshots"
if command -v snapper &>/dev/null && [ -d /etc/snapper/configs ]; then
    shopt -s nullglob
    configs=(/etc/snapper/configs/*)
    shopt -u nullglob
    if [ "${#configs[@]}" -eq 0 ]; then
        warn "snapper installed but no configs found, skipping"
    else
        for cfg in "${configs[@]}"; do
            sudo sed -i 's/TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' "$cfg"
            # supgrade makes 2 snapshots/run (pre+post); 10 keeps ~5 upgrade
            # cycles of rollback history without piling up (or cluttering the
            # GRUB boot menu, if grub-btrfs ends up set up below).
            sudo sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="10"/' "$cfg"
        done
        sudo systemctl disable --now snapper-timeline.timer 2>/dev/null || true
        ok "Timeline snapshots disabled, NUMBER_LIMIT set to 10 for: $(basename -a "${configs[@]}" | tr '\n' ' ')"
    fi
else
    warn "snapper not installed, skipping"
fi

# ============================================================
# 7. Steam library -> its own subvolume, excluded from home snapshots
# ============================================================
step "Steam subvolume"
STEAM_DIR="$HOME/.local/share/Steam"

if findmnt "$STEAM_DIR" &>/dev/null; then
    log "$STEAM_DIR is already a separate mount, skipping"
elif pgrep -x steam >/dev/null; then
    warn "Steam is running — close it and re-run this script to set up the subvolume"
else
    sudo mkdir -p /mnt/btrfs-top
    sudo mount -o subvolid=5 "$ROOT_SRC" /mnt/btrfs-top
    if [[ ! -d /mnt/btrfs-top/@steam ]]; then
        sudo btrfs subvolume create /mnt/btrfs-top/@steam
        ok "Created @steam subvolume"
    fi
    sudo umount /mnt/btrfs-top

    sudo mkdir -p /mnt/newsteam
    sudo mount -o "subvol=/@steam,noatime,compress=zstd:1,datacow" "$ROOT_SRC" /mnt/newsteam
    sudo chown "$(id -u):$(id -g)" /mnt/newsteam

    if [[ -d "$STEAM_DIR" ]] && [ -n "$(ls -A "$STEAM_DIR" 2>/dev/null)" ]; then
        log "Existing Steam data found, migrating into the new subvolume..."
        command -v rsync &>/dev/null || sudo pacman -S --needed --noconfirm rsync
        rsync -aHAX --info=progress2 "$STEAM_DIR"/ /mnt/newsteam/
        mv "$STEAM_DIR" "${STEAM_DIR}.old"
        log "Old data kept at ${STEAM_DIR}.old — verify Steam works, then remove it manually"
    fi

    mkdir -p "$STEAM_DIR"
    sudo umount /mnt/newsteam

    echo -e "UUID=$ROOT_UUID\t$STEAM_DIR\tbtrfs\trw,noatime,compress=zstd:1,datacow,subvol=/@steam\t0 0" | sudo tee -a "$FSTAB" >/dev/null
    sudo systemctl daemon-reload
    sudo mount "$STEAM_DIR"
    ok "$STEAM_DIR is now its own subvolume"
fi

# ============================================================
# 8. GRUB boot-menu snapshot integration (only if GRUB + snapper root)
# ============================================================
step "GRUB snapshot boot integration"
if ! pacman -Qi grub &>/dev/null; then
    warn "GRUB not installed, skipping grub-btrfs"
elif ! command -v snapper &>/dev/null || [ ! -f /etc/snapper/configs/root ]; then
    warn "No snapper root config found, skipping grub-btrfs (it lists snapper snapshots in the boot menu)"
else
    # inotify-tools is what lets grub-btrfsd watch /.snapshots for changes.
    sudo pacman -S --needed --noconfirm grub-btrfs inotify-tools

    # Booting a read-only snapshot needs an overlayfs hook in the initramfs so
    # writes (e.g. a display manager) don't fail. grub-btrfs only ships a
    # hook for classic udev-based initramfs, not systemd-based ones.
    if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
        warn "mkinitcpio uses the systemd hook, which grub-btrfs-overlayfs doesn't support — snapshots will boot read-only"
    elif ! grep -qE '^HOOKS=.*\bgrub-btrfs-overlayfs\b' /etc/mkinitcpio.conf; then
        sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%Y%m%d%H%M%S)"
        sudo sed -i -E 's/^(HOOKS=\(.*)\)/\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
        ok "Added grub-btrfs-overlayfs to mkinitcpio HOOKS and rebuilt the initramfs"
    fi

    # Only "pre" snapshots (the state right before an upgrade) are useful
    # rollback targets — "post" is just "now", so exclude it to halve menu
    # clutter (also why NUMBER_LIMIT was lowered earlier).
    if grep -q '^#GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=' /etc/default/grub-btrfs/config; then
        sudo sed -i 's/^#GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=.*/GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=("post")/' /etc/default/grub-btrfs/config
        ok "Excluding 'post' snapshots from the boot menu"
    fi

    # grub-btrfsd regenerates the snapshot submenu whenever snapper
    # creates or deletes a snapshot; the initial grub-mkconfig adds it now.
    sudo systemctl enable --now grub-btrfsd.service
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "grub-btrfs set up — reboot and check the boot menu for an 'Arch Linux snapshots' submenu"
fi

echo ""
ok "Btrfs optimization complete!"
warn "Recommended: reboot once to confirm the system boots cleanly with the new fstab."
