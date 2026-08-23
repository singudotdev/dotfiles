function supgrade --description 'Upgrade pacman packages, Flatpak apps, and AUR packages, then clean up'
    sudo pacman -Syyu
    flatpak update
    upgrade-aur
    clean-pkgs
end
