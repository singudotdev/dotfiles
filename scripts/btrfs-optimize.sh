#!/bin/bash
set -euo pipefail

# Applies the btrfs tuning used on this workstation to whatever btrfs filesystem
# currently hosts /: drops nodatacow/nodatasum, switches to noatime + zstd
# compression, sets the NVMe I/O scheduler to none, enables periodic scrub,
# turns off snapper's timeline (continuous) snapshots in favor of the
# pre/post pair `supgrade` takes, moves the Steam library into its own
# subvolume so game installs don't bloat home snapshots, and — if Limine is
# installed — sets up limine-snapper-sync so snapshots show up as boot
# entries you can roll back into directly from the boot menu. Installing its
# mkinitcpio hook fully redeploys Limine (new EFI binary, new boot entry,
# rebuilt limine.conf) — your original boot path is kept as a fallback entry.
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

read -rp "This will edit /etc/fstab, remount filesystems live, tune I/O scheduler, enable scrub, disable snapper timeline snapshots, move ~/.local/share/Steam into its own subvolume, and (if Limine is installed) fully redeploy Limine to set up limine-snapper-sync (new EFI binary, new boot entry, rebuilt initramfs) — your original boot path is kept as a fallback entry either way, but reboot and check the boot menu afterward. Continue? (y/n): " confirm
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
            # Limine boot menu, if limine-snapper-sync ends up set up below).
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
# 8. Limine boot-menu snapshot integration (only if Limine + snapper root)
# ============================================================
step "Limine snapshot boot integration"
if ! pacman -Qi limine &>/dev/null; then
    warn "Limine not installed, skipping limine-snapper-sync"
elif ! command -v snapper &>/dev/null || [ ! -f /etc/snapper/configs/root ]; then
    warn "No snapper root config found, skipping limine-snapper-sync (it syncs snapper snapshots into the boot menu)"
else
    install_aur_pkg() {
        local pkg="$1"
        pacman -Qi "$pkg" &>/dev/null && { log "$pkg already installed"; return; }
        local build_dir="/tmp/${pkg}"
        rm -rf "$build_dir"
        git clone "https://aur.archlinux.org/${pkg}.git" "$build_dir" || { warn "Failed to clone $pkg from AUR"; return; }
        (cd "$build_dir" && makepkg -si --noconfirm --needed) || warn "Failed to build/install $pkg"
        rm -rf "$build_dir"
    }

    # Booting a read-only snapshot needs an overlayfs hook in the initramfs so
    # writes (e.g. a display manager) don't fail. Pick the variant matching
    # this system's mkinitcpio style (systemd-based vs classic udev-based).
    initcpio_hook=""
    if [ -f /etc/mkinitcpio.conf ]; then
        if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
            initcpio_hook="sd-btrfs-overlayfs"
        else
            initcpio_hook="btrfs-overlayfs"
        fi
    fi

    install_aur_pkg limine-snapper-sync
    [ -n "$initcpio_hook" ] && install_aur_pkg limine-mkinitcpio-hook

    if ! pacman -Qi limine-snapper-sync &>/dev/null; then
        warn "limine-snapper-sync did not install successfully, skipping the rest of this phase"
    else
        if [ -n "$initcpio_hook" ] && ! grep -qE "\b${initcpio_hook}\b" /etc/mkinitcpio.conf; then
            sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%Y%m%d%H%M%S)"
            sudo sed -i -E "s/^(HOOKS=\(.*\bfilesystems\b)(.*)\$/\1 ${initcpio_hook}\2/" /etc/mkinitcpio.conf
            # limine-mkinitcpio-hook asks "Would you like to run limine-mkinitcpio
            # now? [Y/n]" after building — always yes here, since that resync is
            # the entire point of this phase. `yes` dies from SIGPIPE once
            # mkinitcpio exits, which pipefail would otherwise (mis)report as a
            # failure, so check mkinitcpio's own exit status via PIPESTATUS
            # instead of the pipeline's aggregate one.
            if yes | sudo mkinitcpio -P; then
                mkinitcpio_status=0
            else
                mkinitcpio_status=${PIPESTATUS[1]}
            fi
            [ "$mkinitcpio_status" -eq 0 ] || fail "mkinitcpio -P failed (exit $mkinitcpio_status)"
            ok "Added $initcpio_hook to mkinitcpio HOOKS and rebuilt the initramfs"
        fi

        # limine.conf often isn't directly under the boot mountpoint — e.g. an
        # archinstall UKI setup puts it at <boot>/EFI/BOOT/limine.conf, one
        # level deeper than the generic paths limine-snapper-sync's own
        # auto-detection checks. Find the real file and pin ESP_PATH to it so
        # detection can't miss it.
        boot_mount="$(findmnt -no TARGET /boot 2>/dev/null || echo /boot)"
        limine_conf_dir=""
        for candidate in "$boot_mount" "$boot_mount/EFI/BOOT" "$boot_mount/efi/BOOT" "$boot_mount/limine" "$boot_mount/EFI/Linux"; do
            if sudo test -f "$candidate/limine.conf"; then
                limine_conf_dir="$candidate"
                break
            fi
        done

        if [ -z "$limine_conf_dir" ]; then
            warn "Could not find limine.conf under $boot_mount — skipping the rest of this phase. Find it manually, set ESP_PATH in /etc/limine-snapper-sync.conf, then run 'sudo limine-snapper-sync' yourself."
        else
            log "Found limine.conf at $limine_conf_dir/limine.conf"

            # limine-mkinitcpio-hook's own install can create a NEW limine.conf
            # (e.g. at $boot_mount) while an OLDER one still sits elsewhere
            # (e.g. an archinstall UKI setup originally at EFI/BOOT/limine.conf).
            # Limine's own boot-time config search can then silently prefer
            # the stale file over the new one, ignoring everything
            # limine-snapper-sync writes. Move any other same-named file out
            # of the way so there's exactly one limine.conf to find.
            for candidate in "$boot_mount" "$boot_mount/EFI/BOOT" "$boot_mount/efi/BOOT" "$boot_mount/limine" "$boot_mount/EFI/Linux"; do
                [ "$candidate" = "$limine_conf_dir" ] && continue
                if sudo test -f "$candidate/limine.conf"; then
                    sudo mv "$candidate/limine.conf" "$candidate/limine.conf.disabled"
                    warn "Found a conflicting limine.conf at $candidate — renamed to limine.conf.disabled so Limine can't load it instead of $limine_conf_dir/limine.conf"
                fi
            done

            # Only "pre" snapshots (the state right before an upgrade) are
            # useful rollback targets — "post" is just "now", so exclude it
            # to halve menu clutter (also why NUMBER_LIMIT was lowered earlier).
            if [ -f /etc/limine-snapper-sync.conf ]; then
                if ! grep -q '^ESP_PATH=' /etc/limine-snapper-sync.conf; then
                    echo "ESP_PATH=\"$limine_conf_dir\"" | sudo tee -a /etc/limine-snapper-sync.conf >/dev/null
                fi
                if grep -q '^#EXCLUDE_SNAPSHOT_TYPES' /etc/limine-snapper-sync.conf; then
                    sudo sed -i 's/^#EXCLUDE_SNAPSHOT_TYPES=.*/EXCLUDE_SNAPSHOT_TYPES="post"/' /etc/limine-snapper-sync.conf
                elif ! grep -q '^EXCLUDE_SNAPSHOT_TYPES=' /etc/limine-snapper-sync.conf; then
                    echo 'EXCLUDE_SNAPSHOT_TYPES="post"' | sudo tee -a /etc/limine-snapper-sync.conf >/dev/null
                fi
                ok "Configured limine-snapper-sync: ESP_PATH=$limine_conf_dir, excluding 'post' snapshots from the boot menu"
            fi

            sudo systemctl enable --now limine-snapper-sync.service

            if sudo limine-snapper-sync; then
                ok "limine-snapper-sync ran successfully — reboot and check the boot menu for your OS entry, a nested Snapshots submenu, and an EFI fallback entry"
            else
                warn "limine-snapper-sync reported an issue above — see https://gitlab.com/Zesko/limine-snapper-sync for troubleshooting, or inspect $limine_conf_dir/limine.conf directly"
            fi
        fi
    fi
fi

echo ""
ok "Btrfs optimization complete!"
warn "Recommended: reboot once to confirm the system boots cleanly with the new fstab."
