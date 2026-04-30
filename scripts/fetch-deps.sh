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
# Qwen2.5 0.5B Q4_K_M — ~397MB, smaller and better than TinyLlama 1.1B
MODEL="$MODELS_DIR/qwen2.5-0.5b.gguf"
if [ -f "$MODEL" ]; then
    echo "✓ Qwen2.5 0.5B already downloaded ($(du -sh "$MODEL" | cut -f1))"
else
    echo "▶ Downloading Qwen2.5 0.5B Q4_K_M (~397MB)..."
    curl -L --progress-bar \
        "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf" \
        -o "$MODEL"
    echo "✓ Qwen2.5 0.5B downloaded"
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
