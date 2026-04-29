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

# ── Safe cleanup: read live mounts from /proc/mounts and detach all ──────────
echo ""
echo "▶ Cleaning work directory..."

# Find every mount that lives under our work dir (sorted deepest first so
# child mounts are removed before parents), then lazy-unmount each one.
# Reading /proc/mounts is the only reliable source of truth — guessing paths
# misses mounts that got created by the previous build.
LIVE=$(grep "$WORK" /proc/mounts 2>/dev/null | awk '{print $2}' | sort -r)
if [ -n "$LIVE" ]; then
    echo "  Found live mounts — detaching..."
    echo "$LIVE" | xargs -I{} sudo umount -l {} 2>/dev/null || true
fi

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
