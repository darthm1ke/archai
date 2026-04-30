# AIos Installation Reference

## Check available disks
lsblk
fdisk -l

## Partition a disk (NVMe: use p prefix — /dev/nvme0n1p1)
parted -s /dev/sda mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB set 1 esp on \
  mkpart root ext4 513MiB 100%

## Format partitions
mkfs.fat -F32 /dev/sda1    # EFI
mkfs.ext4 /dev/sda2        # Root

## Mount and install
mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
pacstrap /mnt base linux linux-firmware networkmanager sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

## Inside chroot
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
systemctl enable NetworkManager
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
