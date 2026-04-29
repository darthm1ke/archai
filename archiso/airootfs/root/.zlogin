# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# ── Wait for ArchAI services to be ready ─────────────────────────────────────
# Give systemd a moment to finish bringing up the AI daemon and network
# before we launch the UI — so the user never sees a half-ready system.

_archai_wait_ready() {
    local timeout=30
    local elapsed=0

    # Wait for network (up to 15s)
    while [ $elapsed -lt 15 ]; do
        systemctl is-active --quiet NetworkManager && break
        sleep 1; elapsed=$((elapsed + 1))
    done

    # Wait for AI daemon socket (up to 30s)
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        [ -S /run/archspeech/daemon.sock ] && break
        sleep 1; elapsed=$((elapsed + 1))
    done
}

# Launch the ArchAI UI (tmux split: installer top, execution log bottom)
# Only on tty1 so SSH sessions and other TTYs get a normal shell
if [ "$(tty)" = "/dev/tty1" ]; then
    clear
    _archai_wait_ready
    exec /usr/local/bin/archspeech-ui
fi
