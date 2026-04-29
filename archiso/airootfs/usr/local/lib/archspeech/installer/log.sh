#!/usr/bin/env bash
# Logging helpers — writes to execution log visible in the bottom tmux pane

LOG="/var/log/archspeech/execution.log"
START_TIME=$(date +%s)

log_exec() {
    echo "▶ EXECUTING  $*" >> "$LOG"
}

log_done() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    echo "✓ DONE       $* (${elapsed}s)" >> "$LOG"
}

log_info() {
    echo "  INFO       $*" >> "$LOG"
}

log_warn() {
    echo "⚠ WARNING    $*" >> "$LOG"
}

log_progress() {
    local pct="$1"
    local msg="$2"
    local filled=$(( pct / 4 ))
    local empty=$(( 25 - filled ))
    local bar
    bar="$(printf '%0.s█' $(seq 1 $filled))$(printf '%0.s░' $(seq 1 $empty))"
    echo "  ${bar}  ${pct}% — ${msg}" >> "$LOG"
}

run_logged() {
    local desc="$1"; shift
    log_exec "$desc"
    if "$@" >> "$LOG" 2>&1; then
        log_done "$desc"
        return 0
    else
        log_warn "$desc FAILED (exit $?)"
        return 1
    fi
}
