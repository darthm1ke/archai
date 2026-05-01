#!/usr/bin/env bash
# AIos Local Benchmark
# Tests Qwen3 0.6B on THIS machine with identical settings to the ISO
# Measures: model load time, TTFT, tokens/sec, GPU vs CPU allocation
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
GGUF="$PROJECT/archiso/airootfs/usr/local/lib/archspeech/models/qwen3-0.6b.gguf"
MODEL_NAME="aios-bench"
OLLAMA_URL="http://localhost:11434"
RESULTS="$PROJECT/benchmark-results.txt"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'

print_header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()  { echo -e "  ${GREEN}✓${RESET} $1"; }
info(){ echo -e "  ${CYAN}▶${RESET} $1"; }
warn(){ echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail(){ echo -e "  ${RED}✗${RESET} $1"; }

log() { echo "$1" | tee -a "$RESULTS"; }

# ── Preflight ─────────────────────────────────────────────────────────────────
print_header "AIos Qwen3 0.6B Benchmark"
echo "" > "$RESULTS"
log "AIos Benchmark — $(date)"
log "Machine: $(uname -n)"
log "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
log "Cores: $(nproc)"
log "RAM: $(free -h | awk '/^Mem:/{print $2}')"
log "GPU: $(lspci | grep -i 'vga\|3d\|display' | head -2 | sed 's/.*: //' | tr '\n' ' ')"
log ""

if [ ! -f "$GGUF" ]; then
    fail "GGUF not found at $GGUF"
    echo "  Run: bash scripts/fetch-deps.sh"
    exit 1
fi
ok "GGUF found: $(du -sh "$GGUF" | cut -f1)"

if ! command -v ollama &>/dev/null; then
    warn "Ollama not installed — installing now..."
    sudo pacman -S --noconfirm ollama-vulkan 2>/dev/null || sudo pacman -S --noconfirm ollama
fi
ok "Ollama: $(ollama --version 2>/dev/null || echo 'installed')"

# ── Start Ollama ──────────────────────────────────────────────────────────────
print_header "Starting Ollama"

OLLAMA_RUNNING=false
if curl -sf "$OLLAMA_URL/api/version" &>/dev/null; then
    ok "Ollama already running"
    OLLAMA_RUNNING=true
else
    info "Starting Ollama server..."
    OLLAMA_START_TIME=$(date +%s%N)
    OLLAMA_MODELS=/tmp/aios-bench-models ollama serve &>/tmp/ollama-bench.log &
    OLLAMA_PID=$!

    elapsed=0
    until curl -sf "$OLLAMA_URL/api/version" &>/dev/null; do
        sleep 0.5; elapsed=$((elapsed+1))
        [ $elapsed -gt 60 ] && fail "Ollama failed to start" && exit 1
    done
    OLLAMA_READY_TIME=$(date +%s%N)
    OLLAMA_STARTUP_MS=$(( (OLLAMA_READY_TIME - OLLAMA_START_TIME) / 1000000 ))
    ok "Ollama started in ${OLLAMA_STARTUP_MS}ms"
    log "Ollama startup time: ${OLLAMA_STARTUP_MS}ms"
fi

# ── Import model ──────────────────────────────────────────────────────────────
print_header "Model Import"

SHA256=$(sha256sum "$GGUF" | cut -d' ' -f1)
info "SHA256: ${SHA256:0:16}..."

# Check blob
BLOB_EXISTS=false
if curl -sf --head "$OLLAMA_URL/api/blobs/sha256:$SHA256" &>/dev/null; then
    ok "Blob already in Ollama store"
    BLOB_EXISTS=true
else
    info "Uploading GGUF blob ($(du -sh "$GGUF" | cut -f1))..."
    BLOB_START=$(date +%s%N)

    python3 - <<PYEOF
import urllib.request, os, sys
sha256 = "$SHA256"
gguf   = "$GGUF"
url    = "$OLLAMA_URL"
size   = os.path.getsize(gguf)
sent   = 0
last   = -1

class Reader:
    def __init__(self):
        self.f = open(gguf, 'rb')
        self.sent = 0
    def read(self, n=-1):
        d = self.f.read(1024*1024 if n<0 else n)
        self.sent += len(d)
        pct = int(self.sent/size*100)
        if pct != last:
            print(f"\r  Uploading: {pct}% ({self.sent//1024//1024}/{size//1024//1024}MB)", end='', flush=True)
        return d
    def __len__(self): return size

r = Reader()
req = urllib.request.Request(f"{url}/api/blobs/sha256:{sha256}",
    data=r, method='POST',
    headers={'Content-Type':'application/octet-stream','Content-Length':str(size)})
try:
    urllib.request.urlopen(req, timeout=600)
    print("\n")
except Exception as e:
    print(f"\nUpload error: {e}")
    sys.exit(1)
PYEOF

    BLOB_END=$(date +%s%N)
    BLOB_MS=$(( (BLOB_END - BLOB_START) / 1000000 ))
    BLOB_MB=$(du -m "$GGUF" | cut -f1)
    BLOB_MBS=$(echo "scale=1; $BLOB_MB * 1000 / $BLOB_MS" | bc 2>/dev/null || echo "?")
    ok "Blob uploaded in ${BLOB_MS}ms (~${BLOB_MBS} MB/s)"
    log "Blob upload: ${BLOB_MS}ms at ~${BLOB_MBS} MB/s"
fi

# Always recreate model to pick up latest Modelfile (template changes)
if ollama list 2>/dev/null | grep -q "$MODEL_NAME"; then
    info "Removing old model to apply updated template..."
    ollama rm "$MODEL_NAME" 2>/dev/null || true
fi
if true; then
    info "Creating model '$MODEL_NAME'..."
    CREATE_START=$(date +%s%N)
    curl -sf -X POST "$OLLAMA_URL/api/create" \
        -H 'Content-Type: application/json' \
        -d "{\"model\":\"$MODEL_NAME\",\"files\":{\"model.gguf\":\"sha256:$SHA256\"},\"parameters\":{\"num_ctx\":2048,\"num_predict\":256}}" \
        | python3 -c "import sys,json; [print('  ',json.loads(l).get('status','')) for l in sys.stdin if l.strip()]" 2>/dev/null
    CREATE_END=$(date +%s%N)
    CREATE_MS=$(( (CREATE_END - CREATE_START) / 1000000 ))
    ok "Model created in ${CREATE_MS}ms"
    log "Model create: ${CREATE_MS}ms"
else
    ok "Model '$MODEL_NAME' already exists"
fi

# ── Benchmark ─────────────────────────────────────────────────────────────────
print_header "Inference Benchmark"

run_test() {
    local desc="$1" prompt="$2" gpu_layers="${3:-999}"
    info "Test: $desc"

    local t0=$(date +%s%N)
    local response
    response=$(curl -sf -X POST "$OLLAMA_URL/api/chat" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"$MODEL_NAME\",
            \"messages\": [{\"role\":\"user\",\"content\":\"/no_think\\n$prompt\"}],
            \"think\": false,
            \"stream\": false,
            \"options\": {\"num_ctx\":2048,\"temperature\":0.7,\"num_predict\":256,\"num_gpu\":$gpu_layers}
        }" 2>/dev/null)
    local t1=$(date +%s%N)

    local ms=$(( (t1 - t0) / 1000000 ))
    local content=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',{}).get('content','[no response]')[:120])" 2>/dev/null || echo "[error]")
    local tokens=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eval_count',0))" 2>/dev/null || echo "0")
    local load_ms=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('load_duration',0)//1000000)" 2>/dev/null || echo "0")
    local prompt_ms=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt_eval_duration',0)//1000000)" 2>/dev/null || echo "0")
    local eval_ms=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('eval_duration',0)//1000000)" 2>/dev/null || echo "0")
    local tps=0
    [ "$eval_ms" -gt 0 ] && tps=$(echo "scale=1; $tokens * 1000 / $eval_ms" | bc 2>/dev/null || echo "?")

    echo -e "    ${GREEN}Response${RESET} (${ms}ms total):"
    echo -e "    \"${CYAN}${content}${RESET}\""
    echo -e "    Load: ${load_ms}ms  |  Prefill: ${prompt_ms}ms  |  Generate: ${eval_ms}ms  |  ${BOLD}${tps} tok/s${RESET}"
    echo ""

    log "[$desc]"
    log "  Total: ${ms}ms | Load: ${load_ms}ms | Prefill: ${prompt_ms}ms | Generate: ${eval_ms}ms | Tokens: $tokens | Speed: ${tps} tok/s"
    log "  Response: $content"
    log ""
}

# ── GPU mode (default — uses whatever GPU is available) ───────────────────────
echo -e "\n${BOLD}--- GPU mode ---${RESET}"
run_test "Cold load + simple greeting" "Say hello in one sentence."
run_test "Warm: system command" "How do I update all packages on Arch Linux?"
run_test "Warm: quick question" "What is pacman?"

# ── CPU-only mode (simulates Intel iGPU / slower hardware) ───────────────────
echo -e "\n${BOLD}--- CPU-only mode (simulates Intel iGPU baseline) ---${RESET}"
log "=== CPU-only (num_gpu=0) ==="
run_test "CPU cold: greeting"        "Say hello in one sentence."              0
run_test "CPU warm: system command"  "How do I update all packages on Arch?"   0
run_test "CPU warm: quick question"  "What is pacman?"                         0

# ── GPU info ──────────────────────────────────────────────────────────────────
print_header "GPU Allocation"
RUNNER_INFO=$(curl -sf "$OLLAMA_URL/api/ps" 2>/dev/null || echo "{}")
echo "$RUNNER_INFO" | python3 - <<'PYEOF'
import sys, json
d = json.loads(sys.stdin.read())
for m in d.get('models', []):
    size = m.get('size_vram', 0)
    total = m.get('size', 1)
    pct = int(size/total*100) if total else 0
    print(f"  Model: {m.get('name','?')}")
    print(f"  VRAM:  {size//1024//1024}MB / {total//1024//1024}MB ({pct}% on GPU)")
    print(f"  Until: {m.get('expires_at','?')[:19]}")
PYEOF

log ""
log "Results saved to: $RESULTS"

print_header "Summary"
echo -e "  Full results: ${BOLD}$RESULTS${RESET}"
echo -e "  Compare these numbers to bare metal to isolate performance gaps."
echo ""
