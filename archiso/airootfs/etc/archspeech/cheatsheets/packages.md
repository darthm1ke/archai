# Package Management (Arch / AIos)

## Install a package
sudo pacman -S <package>

## Remove a package
sudo pacman -R <package>

## Remove package and unused dependencies
sudo pacman -Rns <package>

## Search for a package
pacman -Ss <keyword>

## Update all packages
sudo pacman -Syu

## Install from AUR (using yay)
yay -S <package>

## List installed packages
pacman -Q

## Find which package owns a file
pacman -Qo /path/to/file

## Clean package cache
sudo pacman -Sc
