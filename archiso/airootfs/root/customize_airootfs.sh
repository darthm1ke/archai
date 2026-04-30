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
