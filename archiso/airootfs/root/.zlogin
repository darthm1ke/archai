# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# ── Launch ArchAI UI on tty1 only ─────────────────────────────────────────────
if [ "$(tty)" = "/dev/tty1" ]; then
    clear

    # Wait for AI daemon socket — max 30s, then continue anyway
    elapsed=0
    while [ $elapsed -lt 30 ]; do
        [ -S /run/archspeech/daemon.sock ] && break
        sleep 1; elapsed=$((elapsed + 1))
    done

    clear

    # Run installer directly for now (no tmux) so display issues can't hide it
    exec /usr/local/bin/archspeech-installer
fi
