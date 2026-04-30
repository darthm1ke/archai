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

# ── TinyLlama 1.1B Q4_K_M (~640MB) ──────────────────────────────────────────
# Downloaded as GGUF and baked into the ISO. Ollama imports it on first boot
# via aios-model-init.service — no internet needed after that.
# Qwen3 0.6B Q4_K_M — ~400MB, newest Qwen architecture, better than Qwen2.5 0.5B
# Thinking mode disabled at inference time for fast voice responses
MODEL="$MODELS_DIR/qwen3-0.6b.gguf"
if [ -f "$MODEL" ]; then
    echo "✓ Qwen3 0.6B already downloaded ($(du -sh "$MODEL" | cut -f1))"
else
    echo "▶ Downloading Qwen3 0.6B Q4_K_M (~400MB)..."
    curl -L --progress-bar \
        "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf" \
        -o "$MODEL"
    echo "✓ Qwen3 0.6B downloaded"
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
