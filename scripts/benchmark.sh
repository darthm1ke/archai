#!/usr/bin/env bash
# AIos Benchmark — tests qwen2.5:0.5b with GPU and CPU-only modes
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_NAME="qwen2.5:0.5b"
OLLAMA_URL="http://localhost:11434"
RESULTS="$PROJECT/benchmark-results.txt"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'

print_header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()  { echo -e "  ${GREEN}✓${RESET} $1"; }
info(){ echo -e "  ${CYAN}▶${RESET} $1"; }
warn(){ echo -e "  ${YELLOW}⚠${RESET} $1"; }

log() { echo "$1" | tee -a "$RESULTS"; }

# ── Header ────────────────────────────────────────────────────────────────────
print_header "AIos Benchmark — $MODEL_NAME"
echo "" > "$RESULTS"
log "AIos Benchmark — $(date)"
log "Machine: $(uname -n)"
log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
log "Cores: $(nproc)"
log "RAM: $(free -h | awk '/^Mem:/{print $2}')"
log "GPU: $(lspci | grep -i 'vga\|3d\|display' | head -2 | sed 's/.*: //' | tr '\n' ' ')"
log ""

# ── Start Ollama if needed ────────────────────────────────────────────────────
print_header "Ollama"
if ! curl -sf "$OLLAMA_URL/api/version" &>/dev/null; then
    info "Starting Ollama..."
    ollama serve &>/tmp/ollama-bench.log &
    for i in $(seq 1 30); do
        curl -sf "$OLLAMA_URL/api/version" &>/dev/null && break
        sleep 1
    done
fi
ok "Ollama $(curl -sf "$OLLAMA_URL/api/version" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null)"

# ── Model check ───────────────────────────────────────────────────────────────
print_header "Model"
if ollama list 2>/dev/null | grep -q "qwen2.5:0.5b"; then
    ok "$MODEL_NAME ready"
    log "Model: $MODEL_NAME (already available)"
else
    info "Pulling $MODEL_NAME..."
    ollama pull qwen2.5:0.5b
    ok "$MODEL_NAME pulled"
    log "Model: $MODEL_NAME (freshly pulled)"
fi

# ── Benchmark function ────────────────────────────────────────────────────────
run_test() {
    local desc="$1" prompt="$2" gpu_layers="${3:-999}"
    info "Test: $desc"

    local t0=$(date +%s%N)
    local response
    response=$(curl -sf -X POST "$OLLAMA_URL/api/chat" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"$MODEL_NAME\",
            \"messages\": [
                {\"role\":\"system\",\"content\":\"You are AIos, an AI assistant for Arch Linux. Give short direct commands. Use pacman for packages, systemctl for services. Be concise.\"},
                {\"role\":\"user\",\"content\":\"$prompt\"}
            ],
            \"stream\": false,
            \"options\": {
                \"num_ctx\": 2048,
                \"temperature\": 0.7,
                \"num_predict\": 256,
                \"num_gpu\": $gpu_layers
            }
        }" 2>/dev/null)
    local t1=$(date +%s%N)
    local ms=$(( (t1 - t0) / 1000000 ))

    local content load_ms eval_ms tokens tps
    content=$(echo "$response"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',{}).get('content','[no response]')[:150])" 2>/dev/null || echo "[parse error]")
    tokens=$(echo  "$response"  | python3 -c "import sys,json; print(json.load(sys.stdin).get('eval_count',0))"           2>/dev/null || echo "0")
    load_ms=$(echo "$response"  | python3 -c "import sys,json; print(json.load(sys.stdin).get('load_duration',0)//1000000)" 2>/dev/null || echo "0")
    eval_ms=$(echo "$response"  | python3 -c "import sys,json; print(json.load(sys.stdin).get('eval_duration',0)//1000000)" 2>/dev/null || echo "0")
    tps=0
    [ "${eval_ms:-0}" -gt 0 ] && tps=$(echo "scale=1; ${tokens} * 1000 / ${eval_ms}" | bc 2>/dev/null || echo "?")

    echo -e "    ${BOLD}${tps} tok/s${RESET} | ${ms}ms total | load ${load_ms}ms | generate ${eval_ms}ms"
    echo -e "    \"${CYAN}${content}${RESET}\""
    echo ""

    log "[$desc]"
    log "  ${ms}ms total | load ${load_ms}ms | generate ${eval_ms}ms | ${tokens} tokens | ${tps} tok/s"
    log "  > $content"
    log ""
}

# ── GPU tests ─────────────────────────────────────────────────────────────────
print_header "GPU Mode"
run_test "Cold: install nginx"       "install nginx and enable it on boot"
run_test "Warm: update packages"     "update all my packages"
run_test "Warm: disk space"          "how much disk space do I have left"
run_test "Warm: restart service"     "restart the apache service"

# ── CPU-only tests (simulates Intel iGPU baseline) ────────────────────────────
print_header "CPU-only Mode (Intel iGPU simulation)"
log "=== CPU-only (num_gpu=0) ==="
run_test "CPU: install nginx"        "install nginx and enable it on boot"     0
run_test "CPU: update packages"      "update all my packages"                  0
run_test "CPU: disk space"           "how much disk space do I have left"      0

# ── GPU allocation ────────────────────────────────────────────────────────────
print_header "GPU Allocation"
curl -sf "$OLLAMA_URL/api/ps" 2>/dev/null | python3 - <<'PYEOF'
import sys, json
d = json.loads(sys.stdin.read())
for m in d.get('models', []):
    vram  = m.get('size_vram', 0)
    total = m.get('size', 1)
    pct   = int(vram/total*100) if total else 0
    print(f"  {m.get('name','?')}: {vram//1024//1024}MB on GPU / {total//1024//1024}MB total ({pct}% GPU)")
PYEOF

log ""
echo -e "\n  Full results: ${BOLD}$RESULTS${RESET}\n"
