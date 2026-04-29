#!/usr/bin/env bash
# ArchAI Install Profile: Hobby Machine
# Packages: GNOME desktop, browser, media, dev tools, a bit of everything
source /usr/local/lib/archspeech/installer/log.sh

DISK="$1"; USERNAME="$2"; TIMEZONE="$3"; LOCALE="${4:-en_US.UTF-8}"

BASE_PACKAGES="base base-devel linux618 linux618-headers linux-firmware networkmanager sudo git vim zsh"
DESKTOP_PACKAGES="gnome gnome-extra gdm firefox vlc gimp libreoffice-fresh"
DEV_PACKAGES="code docker docker-compose nodejs npm python python-pip rustup go"
ARCHAI_PACKAGES="espeak-ng tmux keyd alsa-utils pipewire pipewire-pulse wireplumber"

log_info "Hobby profile — GNOME + media + dev tools + a bit of everything"
log_progress 0 "Starting hobby machine installation"

parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB set 1 esp on \
  mkpart root ext4 513MiB 100% >> "$LOG" 2>&1

PART_EFI="${DISK}1"; PART_ROOT="${DISK}2"
run_logged "Format" bash -c "mkfs.fat -F32 $PART_EFI && mkfs.ext4 -F $PART_ROOT"
mount "$PART_ROOT" /mnt && mkdir -p /mnt/boot/efi && mount "$PART_EFI" /mnt/boot/efi

log_progress 15 "Installing base system"
run_logged "pacstrap" pacstrap /mnt $BASE_PACKAGES
run_logged "genfstab" bash -c "genfstab -U /mnt >> /mnt/etc/fstab"

log_progress 35 "Configuring system"
arch-chroot /mnt bash -s "$TIMEZONE" "$LOCALE" "$USERNAME" << 'CHROOT'
TIMEZONE="$1"; LOCALE="$2"; USERNAME="$3"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen && locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf && echo "archai" > /etc/hostname
useradd -m -G wheel,audio,video,storage,input,docker -s /bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$USERNAME
CHROOT

log_progress 50 "Installing GNOME desktop"
run_logged "Desktop" arch-chroot /mnt pacman -S --noconfirm $DESKTOP_PACKAGES

log_progress 68 "Installing dev tools"
run_logged "Dev tools" arch-chroot /mnt pacman -S --noconfirm $DEV_PACKAGES

log_progress 80 "Installing ArchAI layer"
run_logged "ArchAI" arch-chroot /mnt pacman -S --noconfirm $ARCHAI_PACKAGES

log_progress 88 "Enabling services"
arch-chroot /mnt systemctl enable NetworkManager gdm docker \
  archspeech.service archspeech-ptt.service keyd

log_progress 93 "Bootloader"
run_logged "GRUB" arch-chroot /mnt bash -c "grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi --bootloader-id=ArchAI && grub-mkconfig -o /boot/grub/grub.cfg"

log_progress 97 "Copying ArchAI files"
cp -r /usr/local/lib/archspeech /mnt/usr/local/lib/
cp -r /usr/local/bin/archspeech* /mnt/usr/local/bin/
cp -r /etc/archspeech /mnt/etc/ && cp -r /etc/keyd /mnt/etc/

log_progress 100 "Hobby machine ready. Go build something."
umount -R /mnt
