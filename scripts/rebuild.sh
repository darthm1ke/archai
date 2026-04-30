#!/usr/bin/env bash
# AIos fast rebuild — wipes only the work directory, preserves all caches.
# Packages, model, and pip wheels are never re-downloaded.
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

MODEL="$PROFILE/airootfs/usr/local/lib/archspeech/models/qwen3-0.6b.gguf"
if [ ! -f "$MODEL" ]; then
    echo "✗ Qwen3 0.6B model not found."
    echo "  Run:  bash $PROJECT/scripts/fetch-deps.sh"
    exit 1
fi

# ── Safe cleanup: read live mounts from /proc/mounts and detach all ──────────
echo ""
echo "▶ Cleaning work directory..."

LIVE=$(grep "$WORK" /proc/mounts 2>/dev/null | awk '{print $2}' | sort -r) || true
if [ -n "$LIVE" ]; then
    echo "  Found live mounts — detaching..."
    echo "$LIVE" | xargs -I{} sudo umount -l {} 2>/dev/null || true
fi

sudo rm -rf "$WORK"
mkdir -p "$OUT"

# ── Build ─────────────────────────────────────────────────────────────────────
echo "▶ Building AIos ISO..."
echo "  Packages cached in:  $PROJECT/pkg-cache/"
echo "  Model:               $(du -sh "$MODEL" | cut -f1) — Qwen3 0.6B"
echo ""

sudo mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

# ── Report ────────────────────────────────────────────────────────────────────
ISO=$(find "$OUT" -name "aios-*.iso" | sort -t- -k2 -V | tail -1)
if [ -f "$ISO" ]; then
    SIZE=$(du -sh "$ISO" | cut -f1)
    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  ✓ AIos ISO ready: $(basename "$ISO")"
    echo "  ✓ Size: $SIZE"
    echo ""
    echo "  Test in VM:"
    echo "  bash $PROJECT/scripts/test-vm.sh"
    echo ""
    echo "  Deploy to Ventoy:"
    echo "  cp $ISO /run/media/\$USER/Ventoy/"
    echo "══════════════════════════════════════════════════════"
    echo ""
else
    echo "✗ Build failed — no aios-*.iso found in $OUT"
    exit 1
fi
