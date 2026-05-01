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

# TinyLlama is pulled on first boot by the daemon (ensure_ollama_model).
# Chroot has no network access so pulling here always fails silently.

# ── Enable core services ──────────────────────────────────────────────────────
systemctl enable ollama.service 2>/dev/null || systemctl enable ollama-vulkan.service 2>/dev/null || true
systemctl enable aios-mount-data.service
systemctl enable aios-model-init.service
systemctl enable archspeech.service
# archspeech-voice.service disabled — uses piper/whisper-cli which aren't installed
# Voice is handled by archspeech-ptt (evdev + espeak-ng)
# systemctl enable archspeech-voice.service
systemctl enable archspeech-ptt.service
systemctl enable keyd.service
systemctl enable NetworkManager.service

# ── File permissions ──────────────────────────────────────────────────────────
chmod 440 /etc/sudoers.d/archspeech
# Make GGUF readable by the ollama system user
chmod 644 /usr/local/lib/archspeech/models/qwen3-0.6b.gguf 2>/dev/null || true
chmod 755 /usr/local/lib/archspeech/models/ 2>/dev/null || true
chmod +x /usr/local/lib/archspeech/installer/profiles/*.sh
chmod +x /usr/local/lib/archspeech/installer/log.sh

echo "ArchAI airootfs customization complete."
