#!/usr/bin/env bash
# Run this ONCE before your first build (or when you want to update a dep).
# Downloads TinyLlama and pip wheels into the source tree so rebuilds are fast.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_DIR="$PROJECT/archiso/airootfs/usr/local/lib/archspeech/models"
WHEELS_DIR="$PROJECT/archiso/airootfs/usr/local/lib/archspeech/wheels"
PKG_CACHE="$PROJECT/pkg-cache"

mkdir -p "$MODELS_DIR" "$WHEELS_DIR" "$PKG_CACHE"

echo ""
echo "══════════════════════════════════════════"
echo "  ArchAI — one-time dependency fetch"
echo "══════════════════════════════════════════"
echo ""

# ── TinyLlama 1.1B Q4_K_M ────────────────────────────────────────────────────
MODEL="$MODELS_DIR/tinyllama.gguf"
if [ -f "$MODEL" ]; then
    echo "✓ TinyLlama already downloaded ($(du -sh "$MODEL" | cut -f1))"
else
    echo "▶ Downloading TinyLlama 1.1B Q4_K_M (~640MB)..."
    curl -L --progress-bar \
        "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" \
        -o "$MODEL"
    echo "✓ TinyLlama downloaded"
fi

# ── pip wheels (pure-Python packages only, cached as wheels) ─────────────────
echo ""
echo "▶ Downloading pip wheels (anthropic, openai)..."
pip download \
    --dest "$WHEELS_DIR" \
    --quiet \
    anthropic openai
echo "✓ Pip wheels cached ($(ls "$WHEELS_DIR" | wc -l) files)"

# evdev: installed via pacman (python-evdev) — no pip wheel needed
# llama-cpp-python: compiles from source — pip caches the build automatically

echo ""
echo "══════════════════════════════════════════"
echo "  All deps ready. Run rebuild.sh to build."
echo "══════════════════════════════════════════"
echo ""
