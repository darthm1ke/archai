#!/usr/bin/env bash
# Fast rebuild — wipes only the work directory, preserves all caches.
# Packages, TinyLlama, and pip wheels are never re-downloaded.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$PROJECT/work"
OUT="$PROJECT/build"
PROFILE="$PROJECT/archiso"

# ── Preflight checks ──────────────────────────────────────────────────────────
if ! command -v mkarchiso &>/dev/null; then
    echo "✗ mkarchiso not found. Run: sudo pacman -S archiso"
    exit 1
fi

MODEL="$PROFILE/airootfs/usr/local/lib/archspeech/models/tinyllama.gguf"
if [ ! -f "$MODEL" ]; then
    echo "✗ TinyLlama model not found."
    echo "  Run:  bash $PROJECT/scripts/fetch-deps.sh"
    exit 1
fi

# ── Safe cleanup: lazy-unmount all chroot mounts before wiping ────────────────
echo ""
echo "▶ Cleaning work directory..."
AIROOTFS="$WORK/x86_64/airootfs"
# Lazy unmount (-l) detaches immediately even with open handles — required for
# kernel virtual filesystems like /proc and /sys inside the chroot
for mount_point in proc/sys/fs/binfmt_misc dev/pts dev/shm sys proc run; do
    sudo umount -l "$AIROOTFS/$mount_point" 2>/dev/null || true
done
sudo umount -l "$AIROOTFS" 2>/dev/null || true
sudo umount -l "$WORK" 2>/dev/null || true
sudo rm -rf "$WORK"
mkdir -p "$OUT"

# ── Build ─────────────────────────────────────────────────────────────────────
echo "▶ Building ISO..."
echo "  Packages cached in:  $PROJECT/pkg-cache/"
echo "  Model pre-staged:    $(du -sh "$MODEL" | cut -f1)"
echo ""

sudo mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

# ── Report ────────────────────────────────────────────────────────────────────
ISO=$(find "$OUT" -name "*.iso" | sort -t- -k3 -V | tail -1)
if [ -f "$ISO" ]; then
    SIZE=$(du -sh "$ISO" | cut -f1)
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  ✓ ISO ready: $ISO"
    echo "  ✓ Size: $SIZE"
    echo ""
    echo "  Boot in VM:"
    echo "  qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \\"
    echo "    -cdrom $ISO \\"
    echo "    -boot d -vga virtio -display gtk"
    echo "══════════════════════════════════════════════════"
    echo ""
else
    echo "✗ Build failed — no ISO found in $OUT"
    exit 1
fi
