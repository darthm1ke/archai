#!/usr/bin/env bash
# ArchAI Install Profile: Home Server
# Packages: headless, nginx, certbot, docker, fail2ban, ssh hardening
source /usr/local/lib/archspeech/installer/log.sh

DISK="$1"
USERNAME="$2"
TIMEZONE="$3"
LOCALE="${4:-en_US.UTF-8}"

BASE_PACKAGES="base base-devel linux618 linux618-headers linux-firmware networkmanager sudo git vim zsh openssh"
SERVER_PACKAGES="nginx certbot certbot-nginx docker docker-compose fail2ban ufw python python-pip"
ARCHAI_PACKAGES="espeak-ng tmux keyd alsa-utils python-pip"

log_info "Server profile — nginx, Docker, SSL, hardened SSH, firewall"
log_progress 0 "Starting home server installation"

parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB set 1 esp on \
  mkpart root ext4 513MiB 100% >> "$LOG" 2>&1

PART_EFI="${DISK}1"; PART_ROOT="${DISK}2"

log_progress 10 "Formatting and mounting"
run_logged "Format EFI"  mkfs.fat -F32 "$PART_EFI"
run_logged "Format root" mkfs.ext4 -F  "$PART_ROOT"
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot/efi && mount "$PART_EFI" /mnt/boot/efi

log_progress 20 "Installing base system"
run_logged "pacstrap" pacstrap /mnt $BASE_PACKAGES
run_logged "genfstab" bash -c "genfstab -U /mnt >> /mnt/etc/fstab"

log_progress 45 "Configuring system"
arch-chroot /mnt bash -s "$TIMEZONE" "$LOCALE" "$USERNAME" << 'CHROOT'
TIMEZONE="$1"; LOCALE="$2"; USERNAME="$3"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen && locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "archai-server" > /etc/hostname
useradd -m -G wheel,docker -s /bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$USERNAME
# Harden SSH
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
CHROOT

log_progress 60 "Installing server stack"
run_logged "Server packages" arch-chroot /mnt pacman -S --noconfirm $SERVER_PACKAGES

log_progress 75 "Installing ArchAI layer"
run_logged "ArchAI packages" arch-chroot /mnt pacman -S --noconfirm $ARCHAI_PACKAGES

log_progress 85 "Enabling services"
arch-chroot /mnt systemctl enable NetworkManager sshd nginx docker fail2ban \
  archspeech.service archspeech-ptt.service keyd

log_progress 92 "Installing bootloader"
run_logged "GRUB" arch-chroot /mnt grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi --bootloader-id=ArchAI
run_logged "GRUB cfg" arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

log_progress 97 "Copying ArchAI files"
cp -r /usr/local/lib/archspeech /mnt/usr/local/lib/
cp -r /usr/local/bin/archspeech* /mnt/usr/local/bin/
cp -r /etc/archspeech /mnt/etc/ && cp -r /etc/keyd /mnt/etc/

log_progress 100 "Server ready. Your data, your rules."
umount -R /mnt
