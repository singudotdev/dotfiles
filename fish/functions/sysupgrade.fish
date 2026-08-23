function sysupgrade --description 'Upgrade pacman packages, Flatpak apps, and AUR packages'
    sudo pacman -Syyu
    flatpak update
    upgrade-aur.sh
end
