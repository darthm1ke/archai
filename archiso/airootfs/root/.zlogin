# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# ── Launch ArchAI UI on tty1 only ─────────────────────────────────────────────
if [ "$(tty)" = "/dev/tty1" ]; then
    # Wait for AI daemon socket — max 30s, then continue anyway
    elapsed=0
    while [ $elapsed -lt 30 ]; do
        [ -S /run/archspeech/daemon.sock ] && break
        sleep 1; elapsed=$((elapsed + 1))
    done

    # Force the VGA console to hand off from kernel to userspace.
    # Without this, the boot messages stay painted on the framebuffer
    # and the installer output is invisible even though it's running.
    printf '\033c'          # ESC c — full terminal reset, clears framebuffer
    sleep 0.3
    printf '\033[?25h'      # show cursor
    tput reset 2>/dev/null  # belt and suspenders

    exec /usr/local/bin/archspeech-installer
fi
