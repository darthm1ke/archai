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
# Qwen2.5 0.5B — no thinking mode, coherent responses, ~390MB
# Pull via Ollama registry so it gets proper templates and config
# Pull qwen2.5:0.5b directly into the ISO staging directory
# OLLAMA_MODELS env var tells Ollama exactly where to store it
OLLAMA_STAGED="$PROJECT/archiso/airootfs/usr/local/lib/archspeech/ollama"
if [ -d "$OLLAMA_STAGED/models/manifests/registry.ollama.ai/library/qwen2.5" ]; then
    echo "✓ Qwen2.5 0.5B already staged ($(du -sh "$OLLAMA_STAGED/models" | cut -f1))"
else
    echo "▶ Pulling qwen2.5:0.5b directly into ISO staging directory..."
    mkdir -p "$OLLAMA_STAGED"
    # Start a temporary Ollama instance pointing at our staging dir
    OLLAMA_MODELS="$OLLAMA_STAGED" ollama serve &>/tmp/ollama-stage.log &
    STAGE_PID=$!
    sleep 3
    OLLAMA_MODELS="$OLLAMA_STAGED" ollama pull qwen2.5:0.5b
    kill $STAGE_PID 2>/dev/null; wait $STAGE_PID 2>/dev/null || true
    echo "✓ Staged: $(du -sh "$OLLAMA_STAGED/models" | cut -f1)"
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
