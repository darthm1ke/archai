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

# Find PulseAudio/PipeWire socket for mic passthrough
PULSE_SOCK="/run/user/$(id -u)/pulse/native"
if [ -S "$PULSE_SOCK" ]; then
    AUDIO_ARGS="-audiodev pa,id=audio0,server=unix:$PULSE_SOCK -device intel-hda -device hda-duplex,audiodev=audio0"
    echo "  Audio: PulseAudio/PipeWire mic passthrough active"
else
    AUDIO_ARGS="-audiodev pipewire,id=audio0 -device intel-hda -device hda-duplex,audiodev=audio0"
    echo "  Audio: PipeWire direct"
fi

echo "▶ Booting $ISO"
echo "  Disk: $DISK"
echo "  SSH:  ssh -o StrictHostKeyChecking=no -p 2222 root@localhost"
echo "  Mic:  Hold Caps Lock inside the VM to speak"
echo ""

# PULSE_SERVER tells QEMU exactly which socket to use for audio
export PULSE_SERVER="unix:$PULSE_SOCK"

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
    $AUDIO_ARGS
