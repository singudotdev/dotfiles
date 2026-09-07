function supgrade --description 'Upgrade pacman packages, Flatpak apps, and AUR packages, then clean up'
    # Authenticate once up front. sudoers timestamp_timeout is 5min, so a long
    # run (pacman + flatpak + AUR build + cleanup) can outlast it and
    # re-prompt for a password right at the tail end. `sudo -v` refreshed
    # right before each phase closes that gap — a single long-running sudo'd
    # command (like pacman -Syyu itself) never needs to re-authenticate
    # mid-run regardless of duration, so refreshing at the boundaries between
    # phases is enough; no background process needed.
    sudo -v

    set -l has_root_snapper (test -f /etc/snapper/configs/root; and echo yes)
    set -l has_home_snapper (test -f /etc/snapper/configs/home; and echo yes)

    set -l pre_root
    set -l pre_home
    if command -q snapper
        test "$has_root_snapper" = yes; and set pre_root (sudo snapper -c root create --type pre --print-number --description supgrade)
        test "$has_home_snapper" = yes; and set pre_home (sudo snapper -c home create --type pre --print-number --description supgrade)
    end

    sudo -v
    sudo pacman -Syyu --noconfirm

    sudo -v
    flatpak update --assumeyes
    upgrade-aur
    clean-pkgs

    sudo -v
    test -n "$pre_root"; and sudo snapper -c root create --type post --pre-number $pre_root --description supgrade
    test -n "$pre_home"; and sudo snapper -c home create --type post --pre-number $pre_home --description supgrade
end
