#!/usr/bin/env bash
# Runs inside the airootfs chroot at build time.
set -uo pipefail

# ── Python venv + AI SDKs ─────────────────────────────────────────────────────
# --system-site-packages gives the venv access to python-evdev from pacman
python -m venv --system-site-packages /opt/archspeech
WHEELS="/usr/local/lib/archspeech/wheels"

if [ -d "$WHEELS" ] && [ "$(ls -A "$WHEELS")" ]; then
    /opt/archspeech/bin/pip install --quiet --no-index --find-links "$WHEELS" \
        anthropic openai
else
    /opt/archspeech/bin/pip install --quiet anthropic openai
fi

# No llama-cpp-python — Ollama handles local inference with automatic
# GPU detection (CUDA, ROCm, CPU). Pre-compiled, no chroot build issues.

# ── Ollama model pre-pull ─────────────────────────────────────────────────────
# Pull TinyLlama so it's available offline on first boot.
# Ollama stores models in /usr/share/ollama/.ollama/models/
mkdir -p /usr/share/ollama/.ollama/models
export OLLAMA_MODELS=/usr/share/ollama/.ollama/models

# Start ollama in background, pull the model, then stop it
ollama serve &
OLLAMA_PID=$!
sleep 3
ollama pull tinyllama && echo "TinyLlama pulled successfully" || echo "TinyLlama pull failed — will download on first run"
kill $OLLAMA_PID 2>/dev/null || true
wait $OLLAMA_PID 2>/dev/null || true

# ── Enable core services ──────────────────────────────────────────────────────
systemctl enable ollama.service
systemctl enable archspeech.service
systemctl enable archspeech-voice.service
systemctl enable archspeech-ptt.service
systemctl enable keyd.service
systemctl enable NetworkManager.service

# ── File permissions ──────────────────────────────────────────────────────────
chmod 440 /etc/sudoers.d/archspeech
chmod +x /usr/local/lib/archspeech/installer/profiles/*.sh
chmod +x /usr/local/lib/archspeech/installer/log.sh

echo "ArchAI airootfs customization complete."
