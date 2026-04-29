#!/usr/bin/env bash
# Runs inside the airootfs chroot at build time.
set -euo pipefail

# ── Python venv + AI SDKs ─────────────────────────────────────────────────────
# --system-site-packages gives the venv access to python-evdev installed via pacman
# so we never need to compile it from source
python -m venv --system-site-packages /opt/archspeech
WHEELS="/usr/local/lib/archspeech/wheels"

# Install pure-Python packages from pre-downloaded wheels (fast, no network)
if [ -d "$WHEELS" ] && [ "$(ls -A "$WHEELS")" ]; then
    /opt/archspeech/bin/pip install --quiet --no-index --find-links "$WHEELS" \
        anthropic openai
else
    /opt/archspeech/bin/pip install --quiet anthropic openai
fi

# llama-cpp-python compiled with Vulkan — works on AMD, Intel, and NVIDIA
# at runtime. Falls back to CPU automatically if no Vulkan GPU is found.
CMAKE_ARGS="-DGGML_VULKAN=ON" /opt/archspeech/bin/pip install --quiet llama-cpp-python

# TinyLlama is pre-staged in airootfs/usr/local/lib/archspeech/models/
# by fetch-deps.sh — nothing to download here.

# ── Enable core services ──────────────────────────────────────────────────────
# archspeech-setup is launched from root's .zlogin (inside getty session)
# — not as a competing systemd service
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
