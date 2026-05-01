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
# Models go on the Ventoy USB beside the ISO — NOT inside the squashfs
# This keeps the ISO small and prevents boot hangs from large squashfs decompression
VENTOY="/run/media/$USER/Ventoy"
OLLAMA_STAGED="$VENTOY/aios-data/ollama"
if [ -d "$OLLAMA_STAGED/models/manifests/registry.ollama.ai/library/qwen2.5" ]; then
    echo "✓ Qwen2.5 0.5B already staged ($(du -sh "$OLLAMA_STAGED/models" | cut -f1))"
else
    echo "▶ Pulling qwen2.5:0.5b..."
    ollama pull qwen2.5:0.5b 2>/dev/null || true

    # Find where Ollama stored it (varies by setup) and copy to staging
    MODEL_SRC=$(find /tmp /var/lib/ollama "$HOME/.ollama" -name "0.5b" -path "*/qwen2.5/*" 2>/dev/null | head -1 | sed 's|/manifests/.*||')
    if [ -z "$MODEL_SRC" ]; then
        # Try manifest path
        MODEL_SRC=$(find /tmp /var/lib/ollama "$HOME/.ollama" -path "*/manifests/registry.ollama.ai/library/qwen2.5" -type d 2>/dev/null | head -1 | sed 's|/manifests/.*||')
    fi

    if [ -n "$MODEL_SRC" ] && [ -d "$MODEL_SRC" ]; then
        mkdir -p "$OLLAMA_STAGED/models"
        [ -d "$MODEL_SRC/blobs" ]     && cp -r "$MODEL_SRC/blobs"     "$OLLAMA_STAGED/models/"
        [ -d "$MODEL_SRC/manifests" ] && cp -r "$MODEL_SRC/manifests" "$OLLAMA_STAGED/models/"
        echo "✓ Staged from $MODEL_SRC — $(du -sh "$OLLAMA_STAGED/models" | cut -f1)"
    else
        echo "✗ Could not find model — run fetch-deps.sh again after: ollama pull qwen2.5:0.5b"
    fi
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

# ── Whisper base model (~142MB) ───────────────────────────────────────────────
# Pre-stage so voice-to-text works offline on first boot.
# Whisper looks for models in ~/.cache/whisper/ — we stage to root's cache in airootfs.
WHISPER_DEST="$VENTOY/aios-data/whisper"
WHISPER_MODEL="$WHISPER_DEST/base.pt"

if [ -f "$WHISPER_MODEL" ]; then
    echo "✓ Whisper base model already on Ventoy ($(du -sh "$WHISPER_MODEL" | cut -f1))"
else
    echo "▶ Downloading Whisper base model (~142MB) to Ventoy..."
    mkdir -p "$WHISPER_DEST"
    curl -L --progress-bar \
        "https://openaipublic.azureedge.net/main/whisper/models/ed3a0b6b1c0edf879ad9b11b1af5a0e6ab5db9205f891f668f8b0e6c6326e34e/base.pt" \
        -o "$WHISPER_MODEL"
    echo "✓ Whisper base model on Ventoy"
fi

echo ""
echo "══════════════════════════════════════════"
echo "  All deps ready. Run rebuild.sh to build."
echo "══════════════════════════════════════════"
echo ""
