#!/usr/bin/env bash
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
ISO=$(find "$PROJECT/build" -name "*.iso" | sort | tail -1)
DISK="$PROJECT/archai-test.qcow2"

if [ ! -f "$ISO" ]; then
    echo "✗ No ISO found in $PROJECT/build/ — run rebuild.sh first"
    exit 1
fi

if [ ! -f "$DISK" ]; then
    echo "▶ Creating 20GB virtual disk..."
    qemu-img create -f qcow2 "$DISK" 20G
fi

echo "▶ Booting $ISO"
echo "  Disk: $DISK"
echo "  SSH:  ssh -o StrictHostKeyChecking=no -p 2222 root@localhost"
echo ""

qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -cdrom "$ISO" \
    -drive "file=$DISK,format=qcow2" \
    -boot d \
    -vga std \
    -display gtk \
    -net "user,hostfwd=tcp::2222-:22" \
    -net nic \
    -audiodev pipewire,id=audio0 \
    -device intel-hda \
    -device "hda-duplex,audiodev=audio0"
