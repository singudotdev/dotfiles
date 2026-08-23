function sysupgrade --description 'Upgrade pacman packages, Flatpak apps, and AUR packages'
    sudo pacman -Syyu
    flatpak update
    update-aur-packages.sh
end
