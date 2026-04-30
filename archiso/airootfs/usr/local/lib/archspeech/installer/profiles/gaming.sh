#!/usr/bin/env bash
# ArchAI Install Profile: Gaming Rig
# Packages: full desktop (KDE), Steam, Proton, GameMode, Wine, Discord
source /usr/local/lib/archspeech/installer/log.sh
source /usr/local/lib/archspeech/installer/common.sh

DISK="$1"
USERNAME="$2"
TIMEZONE="$3"
LOCALE="${4:-en_US.UTF-8}"

BASE_PACKAGES="base base-devel linux618 linux618-headers linux-firmware networkmanager sudo git vim zsh"
DESKTOP_PACKAGES="plasma-meta sddm konsole dolphin firefox"
GAMING_PACKAGES="steam lutris wine wine-mono gamemode lib32-gamemode discord"
# Auto-detect GPU and install appropriate driver
if lspci | grep -qi nvidia; then
    DRIVER_PACKAGES="nvidia-dkms nvidia-utils lib32-nvidia-utils vulkan-icd-loader"
    log_info "NVIDIA GPU detected — installing proprietary driver"
elif lspci | grep -qi "amd\|radeon"; then
    DRIVER_PACKAGES="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon"
    log_info "AMD GPU detected — installing Mesa/RADV"
else
    DRIVER_PACKAGES="mesa vulkan-intel lib32-mesa"
    log_info "Intel GPU detected — installing Mesa"
fi
ARCHAI_PACKAGES="python python-pip espeak-ng tmux keyd alsa-utils pipewire pipewire-pulse wireplumber"

log_info "Gaming profile selected — KDE + Steam + Proton + GameMode"
log_progress 0 "Starting gaming rig installation"

# ── Partition ─────────────────────────────────────────────────────────────────
log_progress 5 "Partitioning $DISK"
parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart root ext4 513MiB 100% >> "$LOG" 2>&1

PART_EFI="$(part "$DISK" 1)"
PART_ROOT="$(part "$DISK" 2)"

log_progress 10 "Formatting partitions"
run_logged "Format EFI"  mkfs.fat -F32 "$PART_EFI"
run_logged "Format root" mkfs.ext4 -F  "$PART_ROOT"

log_progress 15 "Mounting"
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$PART_EFI" /mnt/boot/efi

# ── Base install ──────────────────────────────────────────────────────────────
log_progress 20 "Installing base system (this takes a few minutes)"
run_logged "pacstrap base" pacstrap /mnt $BASE_PACKAGES

log_progress 40 "Generating fstab"
run_logged "genfstab" bash -c "genfstab -U /mnt >> /mnt/etc/fstab"

# ── Chroot config ─────────────────────────────────────────────────────────────
log_progress 45 "Configuring system"
arch-chroot /mnt bash -s "$TIMEZONE" "$LOCALE" "$USERNAME" "$PART_ROOT" << 'CHROOT'
TIMEZONE="$1"; LOCALE="$2"; USERNAME="$3"; PART_ROOT="$4"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "archai" > /etc/hostname
useradd -m -G wheel,audio,video,storage,input -s /bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/$USERNAME
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm
CHROOT

log_progress 55 "Installing desktop environment (KDE)"
run_logged "Desktop packages" arch-chroot /mnt pacman -S --noconfirm $DESKTOP_PACKAGES

log_progress 65 "Installing gaming stack (Steam, Proton, GameMode)"
run_logged "Gaming packages" arch-chroot /mnt pacman -S --noconfirm $GAMING_PACKAGES

log_progress 75 "Installing GPU drivers"
run_logged "Driver packages" arch-chroot /mnt pacman -S --noconfirm $DRIVER_PACKAGES

log_progress 82 "Installing ArchAI layer"
run_logged "ArchAI packages" arch-chroot /mnt pacman -S --noconfirm $ARCHAI_PACKAGES

log_progress 88 "Enabling services"
arch-chroot /mnt bash << 'SERVICES'
systemctl enable NetworkManager sddm
systemctl enable archspeech.service archspeech-ptt.service keyd
SERVICES

log_progress 93 "Installing bootloader"
run_logged "GRUB install" arch-chroot /mnt grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi --bootloader-id=ArchAI
run_logged "GRUB config"  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

log_progress 98 "Copying ArchAI files"
cp -r /usr/local/lib/archspeech /mnt/usr/local/lib/
cp -r /usr/local/bin/archspeech* /mnt/usr/local/bin/
cp -r /etc/archspeech /mnt/etc/
cp -r /etc/keyd /mnt/etc/

log_progress 100 "Gaming rig ready. Steam awaits."
log_info "Unmounting — safe to reboot."
umount -R /mnt
