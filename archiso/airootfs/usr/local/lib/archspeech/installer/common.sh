#!/usr/bin/env bash
# Shared helpers for all ArchAI install profiles

# Get partition names correctly for both NVMe and SATA/USB drives.
# NVMe: /dev/nvme0n1 → /dev/nvme0n1p1, /dev/nvme0n1p2
# SATA: /dev/sda    → /dev/sda1,       /dev/sda2
# MMC:  /dev/mmcblk0 → /dev/mmcblk0p1, /dev/mmcblk0p2
part() {
    local disk="$1" num="$2"
    if echo "$disk" | grep -qE "nvme|mmcblk"; then
        echo "${disk}p${num}"
    else
        echo "${disk}${num}"
    fi
}
