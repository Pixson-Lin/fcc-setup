#!/usr/bin/env bash
# =============================================================================
# free-claude-code 懶人安裝包
# 支援: Ubuntu/Debian Linux
# 用法: curl -fsSL https://your-host/install.sh | bash
#   或: bash install.sh
#   帶 key: NVIDIA_NIM_API_KEY="nvapi-xxx" bash install.sh
# =============================================================================

set -euo pipefail

# ── 顏色輸出 ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── 設定區（依需求修改這裡）──────────────────────────────────────────────────
FCC_CONFIG_DIR="$HOME/.config/free-claude-code"
FCC_ENV="$FCC_CONFIG_DIR/.env"
FCC_PORT=8082
FCC_LOG_DIR="$HOME/.local/share/free-claude-code/logs"

# Model 路由設定（依需求調整）
MODEL_DEFAULT="nvidia_nim/mistralai/mistral-nemotron"
MODEL_OPUS="nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct"
MODEL_SONNET="nvidia_nim/mistralai/mistral-nemotron"
MODEL_HAIKU="nvidia_nim/stepfun-ai/step-3.5-flash"

# Rate limit（NIM 免費層建議保持這個值）
RATE_LIMIT=1
RATE_WINDOW=3
MAX_CONCURRENCY=3

ANTHROPIC_AUTH_TOKEN="freecc"

FCC_SETUP_VERSION="1.3.1"
FCC_MANIFEST="$FCC_CONFIG_DIR/install-manifest.json"
FCC_ARCHIVE_URL="https://github.com/Alishahryar1/free-claude-code/archive/refs/heads/main.zip"
FCC_API_COMMITS="https://api.github.com/repos/Alishahryar1/free-claude-code/commits/main"
FCC_EXTRACT_DIR="free-claude-code-main"
# ─────────────────────────────────────────────────────────────────────────────

MANIFEST_ENTRIES=()

manifest_add() {
  MANIFEST_ENTRIES+=("$1")
}

write_manifest() {
  mkdir -p "$FCC_CONFIG_DIR"
  local installed_at
  installed_at="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
  {
    echo '{'
    echo "  \"fcc_setup_version\": \"$FCC_SETUP_VERSION\","
    echo "  \"installed_at\": \"$installed_at\","
    echo '  "platform": "linux",'
    echo '  "items": ['
    local i
    for i in "${!MANIFEST_ENTRIES[@]}"; do
      [[ $i -gt 0 ]] && echo ','
      echo "    ${MANIFEST_ENTRIES[$i]}"
    done
    echo '  ]'
    echo '}'
  } > "$FCC_MANIFEST"
  success "安裝紀錄已寫入 $FCC_MANIFEST"
}

banner() {
  echo -e "${BOLD}"
  echo "╔════════════════════════════════════════╗"
  echo "║   free-claude-code 懶人安裝包 (Linux)  ║"
  echo "╚════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Step 1: 取得 API Key ─────────────────────────────────────────────────────
get_api_key() {
  if [[ -n "${NVIDIA_NIM_API_KEY:-}" ]]; then
    info "使用環境變數中的 NVIDIA_NIM_API_KEY"
    return
  fi
  if [[ -f "$FCC_ENV" ]] && grep -q "NVIDIA_NIM_API_KEY=" "$FCC_ENV" 2>/dev/null; then
    local existing masked new_key
    existing=$(grep "NVIDIA_NIM_API_KEY=" "$FCC_ENV" | cut -d= -f2- | tr -d '"')
    if [[ -n "$existing" && "$existing" != '""' ]]; then
      if [[ ${#existing} -le 12 ]]; then
        masked="***"
      else
        masked="${existing:0:8}...${existing: -4}"
      fi
      echo ""
      echo -e "${YELLOW}偵測到已有 API key：${masked}${NC}"
      echo -e "  按 Enter 沿用，或輸入新 key 覆蓋"
      echo -n "  API Key (nvapi-...): "
      read -r new_key
      if [[ -n "$new_key" ]]; then
        NVIDIA_NIM_API_KEY="$new_key"
      else
        info "沿用既有 API key"
        NVIDIA_NIM_API_KEY="$existing"
      fi
      return
    fi
  fi
  echo ""
  echo -e "${YELLOW}請輸入 NVIDIA NIM API Key${NC}"
  echo -e "  申請網址: ${CYAN}https://build.nvidia.com/settings/api-keys${NC}"
  echo -n "  API Key (nvapi-...): "
  read -r NVIDIA_NIM_API_KEY
  if [[ -z "$NVIDIA_NIM_API_KEY" ]]; then
    error "API Key 不能為空"
  fi
}

# ── Step 2: 安裝 uv ──────────────────────────────────────────────────────────
install_uv() {
  local existed=false uv_path
  if command -v uv &>/dev/null; then
    existed=true
    success "uv 已安裝 ($(uv --version))"
    uv self update 2>/dev/null || true
  else
    info "安裝 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    if ! command -v uv &>/dev/null; then
      error "uv 安裝失敗，請手動安裝: https://docs.astral.sh/uv/"
    fi
    success "uv 安裝完成"
  fi
  uv_path="$(command -v uv)"
  if $existed; then
    manifest_add "{\"id\":\"uv\",\"method\":\"astral-installer\",\"installed_by_script\":false,\"path\":\"$uv_path\"}"
  else
    manifest_add "{\"id\":\"uv\",\"method\":\"astral-installer\",\"installed_by_script\":true,\"path\":\"$uv_path\"}"
  fi
}

# ── Step 3: 安裝 Python 3.14 ─────────────────────────────────────────────────
install_python() {
  local had314=false
  if uv python list 2>/dev/null | grep -q "3.14"; then
    had314=true
    success "Python 3.14 已安裝"
  else
    info "安裝 Python 3.14..."
    uv python install 3.14
    success "Python 3.14 安裝完成"
  fi
  if $had314; then
    manifest_add '{"id":"python","version":"3.14","installed_by_script":false}'
  else
    manifest_add '{"id":"python","version":"3.14","installed_by_script":true}'
  fi
}

# ── Step 3b: 安裝 Node.js ────────────────────────────────────────────────────
install_node() {
  if command -v npm &>/dev/null; then
    success "Node.js 已安裝"
    manifest_add '{"id":"nodejs","installed_by_script":false,"method":"existing"}'
    return
  fi
  info "安裝 Node.js (apt)..."
  if sudo apt-get update -qq && sudo apt-get install -y nodejs npm; then
    success "Node.js 安裝完成"
    manifest_add '{"id":"nodejs","installed_by_script":true,"method":"apt"}'
  else
    error "Node.js 安裝失敗。請至 https://nodejs.org 手動安裝後重試。"
  fi
}

# ── Step 4: 安裝 Claude Code ─────────────────────────────────────────────────
install_claude_code() {
  local had_claude=false
  if command -v claude &>/dev/null; then
    had_claude=true
    success "Claude Code 已安裝"
  else
    info "安裝 Claude Code..."
    npm install -g @anthropic-ai/claude-code
    success "Claude Code 安裝完成"
  fi
  if $had_claude; then
    manifest_add '{"id":"claude-code","method":"npm-global","package":"@anthropic-ai/claude-code","installed_by_script":false}'
  else
    manifest_add '{"id":"claude-code","method":"npm-global","package":"@anthropic-ai/claude-code","installed_by_script":true}'
  fi
}

get_fcc_main_commit() {
  curl -fsSL -H "User-Agent: fcc-setup/$FCC_SETUP_VERSION" "$FCC_API_COMMITS" |
    grep -o '"sha":"[a-f0-9]\{40\}"' | head -1 | cut -d'"' -f4
}

stop_fcc() {
  systemctl --user stop free-claude-code 2>/dev/null || true
  pkill -f 'free-claude-code' 2>/dev/null || true
  sleep 2
}

# ── Step 5: 安裝 free-claude-code proxy ──────────────────────────────────────
install_fcc() {
  local commit_before commit_after commit tmpdir zip extract_root src_dir pkg_version short_sha
  stop_fcc
  commit_before="$(get_fcc_main_commit)"
  tmpdir="$(mktemp -d)"
  zip="$tmpdir/main.zip"
  extract_root="$tmpdir/extract"
  mkdir -p "$extract_root"

  info "下載 free-claude-code (main)..."
  curl -fsSL -o "$zip" "$FCC_ARCHIVE_URL"

  commit_after="$(get_fcc_main_commit)"
  commit="$commit_after"
  if [[ "$commit_after" != "$commit_before" ]]; then
    warn "main 分支 commit 在下載期間變動，使用下載後 commit: ${commit:0:7}"
  fi

  if command -v unzip &>/dev/null; then
    unzip -q "$zip" -d "$extract_root"
  elif command -v python3 &>/dev/null; then
    python3 -m zipfile -e "$zip" "$extract_root"
  else
    rm -rf "$tmpdir"
    error "需要 unzip 或 python3 以解壓 main.zip"
  fi

  src_dir="$extract_root/$FCC_EXTRACT_DIR"
  if [[ ! -d "$src_dir" ]]; then
    rm -rf "$tmpdir"
    error "解壓後找不到目錄 $FCC_EXTRACT_DIR"
  fi

  pkg_version="$(grep -E '^\s*version\s*=' "$src_dir/pyproject.toml" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
  short_sha="${commit:0:7}"
  if [[ -n "$pkg_version" ]]; then
    info "安裝 free-claude-code ($short_sha, v$pkg_version)..."
  else
    info "安裝 free-claude-code ($short_sha)..."
  fi

  uv tool install "$src_dir" --force || {
    warn "安裝受阻，再次停止程序後重試..."
    stop_fcc
    sleep 3
    uv tool install "$src_dir" --force
  }

  local uv_bin
  uv_bin="$(uv tool dir)/../bin"
  if [[ ":$PATH:" != *":$uv_bin:"* ]]; then
    export PATH="$uv_bin:$PATH"
  fi

  rm -rf "$tmpdir"

  if [[ -n "$pkg_version" ]]; then
    success "free-claude-code 安裝完成 ($short_sha, v$pkg_version)"
    manifest_add "{\"id\":\"free-claude-code\",\"method\":\"github-archive\",\"ref\":\"main\",\"commit\":\"$commit\",\"url\":\"$FCC_ARCHIVE_URL\",\"extract_dir\":\"$FCC_EXTRACT_DIR\",\"package_version\":\"$pkg_version\",\"installed_by_script\":true}"
  else
    success "free-claude-code 安裝完成 ($short_sha)"
    manifest_add "{\"id\":\"free-claude-code\",\"method\":\"github-archive\",\"ref\":\"main\",\"commit\":\"$commit\",\"url\":\"$FCC_ARCHIVE_URL\",\"extract_dir\":\"$FCC_EXTRACT_DIR\",\"installed_by_script\":true}"
  fi
}

# ── Step 6: 寫入設定檔 ────────────────────────────────────────────────────────
write_config() {
  info "寫入設定檔 $FCC_ENV ..."
  mkdir -p "$FCC_CONFIG_DIR"
  cat > "$FCC_ENV" <<EOF
# free-claude-code 設定檔
# 由安裝腳本自動產生 - $(date '+%Y-%m-%d %H:%M:%S')

# ── API Keys ──────────────────────────────────
NVIDIA_NIM_API_KEY="${NVIDIA_NIM_API_KEY}"
ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN}"

# ── Model 路由 ────────────────────────────────
MODEL="${MODEL_DEFAULT}"
MODEL_OPUS="${MODEL_OPUS}"
MODEL_SONNET="${MODEL_SONNET}"
MODEL_HAIKU="${MODEL_HAIKU}"

# ── Rate Limit（NIM 免費層：40 req/min）───────
PROVIDER_RATE_LIMIT=${RATE_LIMIT}
PROVIDER_RATE_WINDOW=${RATE_WINDOW}
PROVIDER_MAX_CONCURRENCY=${MAX_CONCURRENCY}

# ── Server ────────────────────────────────────
PORT=${FCC_PORT}

# ── Timeouts ──────────────────────────────────
HTTP_READ_TIMEOUT=120
HTTP_WRITE_TIMEOUT=10
HTTP_CONNECT_TIMEOUT=10

# ── 其他 Provider（有需要再填）────────────────
OPENROUTER_API_KEY=""
DEEPSEEK_API_KEY=""
OLLAMA_BASE_URL="http://localhost:11434"
LM_STUDIO_BASE_URL="http://localhost:1234/v1"
EOF
  chmod 600 "$FCC_ENV"
  success "設定檔寫入完成"
}

# ── Step 7: 建立 systemd service ─────────────────────────────────────────────
install_systemd_service() {
  local service_name="free-claude-code"
  local service_file="$HOME/.config/systemd/user/${service_name}.service"
  local fcc_bin
  fcc_bin="$(command -v free-claude-code 2>/dev/null || echo "$HOME/.local/bin/free-claude-code")"

  mkdir -p "$HOME/.config/systemd/user"
  mkdir -p "$FCC_LOG_DIR"

  info "建立 systemd user service..."
  cat > "$service_file" <<EOF
[Unit]
Description=Free Claude Code Proxy
After=network.target

[Service]
Type=simple
ExecStart=${fcc_bin}
Restart=on-failure
RestartSec=5s
EnvironmentFile=${FCC_ENV}
StandardOutput=append:${FCC_LOG_DIR}/fcc.log
StandardError=append:${FCC_LOG_DIR}/fcc-error.log

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable "$service_name"
  systemctl --user start "$service_name" || warn "Service 啟動失敗，請稍後手動執行: systemctl --user start $service_name"

  # 讓 user service 在未登入時也能運行
  loginctl enable-linger "$USER" 2>/dev/null || warn "loginctl enable-linger 失敗（可能需要 sudo）"

  success "systemd service 安裝完成"
}

# ── Step 8: 寫入 shell alias ─────────────────────────────────────────────────
write_aliases() {
  local alias_block
  alias_block=$(cat <<'ALIASES'

# ── free-claude-code aliases ──────────────────
alias fcc-status='systemctl --user status free-claude-code'
alias fcc-start='systemctl --user start free-claude-code'
alias fcc-stop='systemctl --user stop free-claude-code'
alias fcc-restart='systemctl --user restart free-claude-code'
fcc-log() {
  local log_dir="$HOME/.local/share/free-claude-code/logs"
  local stdout="$log_dir/fcc.log" stderr="$log_dir/fcc-error.log"
  echo -e "\033[0;36mfcc-log\033[0m"
  echo "  stdout: $stdout"
  echo "  stderr: $stderr"
  echo ""
  local files=()
  [[ -f "$stdout" ]] && files+=("$stdout")
  [[ -f "$stderr" ]] && files+=("$stderr")
  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "\033[1;33m尚無 log 檔\033[0m"
    return 1
  fi
  for f in "${files[@]}"; do
    echo -e "\033[90m--- $f (recent 100) ---\033[0m"
    tail -n 100 "$f"
    echo ""
  done
  echo -e "\033[90m--- live (Ctrl+C to exit) ---\033[0m"
  tail -n 0 -f "${files[@]}"
}
alias fcc-claude='ANTHROPIC_AUTH_TOKEN="freecc" ANTHROPIC_BASE_URL="http://localhost:8082" CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 claude'
# ─────────────────────────────────────────────
ALIASES
)

  local marker="# ── free-claude-code aliases"
  local end_marker="# ─────────────────────────────────────────────"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    if grep -q "free-claude-code aliases" "$rc" 2>/dev/null; then
      sed -i "/${marker}/,/${end_marker}/d" "$rc" 2>/dev/null || \
        sed -i '' "/${marker}/,/${end_marker}/d" "$rc" 2>/dev/null || true
      echo "$alias_block" >> "$rc"
      success "Alias 已更新 $(basename "$rc")"
    else
      echo "$alias_block" >> "$rc"
      success "Alias 已寫入 $(basename "$rc")"
    fi
  done
}

# ── Step 9: 驗證 ─────────────────────────────────────────────────────────────
verify() {
  info "等待 proxy 啟動..."
  sleep 3
  if curl -sf "http://localhost:${FCC_PORT}/v1/models" \
       -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" &>/dev/null; then
    success "Proxy 運行正常！"
  else
    warn "Proxy 還未回應，可能還在啟動中。請稍後執行: fcc-status"
  fi
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
main() {
  banner
  get_api_key
  install_uv
  install_python
  install_node
  install_claude_code
  install_fcc
  write_config
  install_systemd_service
  write_aliases

  manifest_add "{\"id\":\"config\",\"path\":\"$FCC_ENV\"}"
  manifest_add '{"id":"service","type":"systemd-user","name":"free-claude-code"}'
  manifest_add '{"id":"shell-aliases","target":"bashrc"}'
  write_manifest

  verify

  echo ""
  echo -e "${BOLD}${GREEN}✓ 安裝完成！${NC}"
  echo ""
  echo -e "  重新載入 shell 後可使用以下指令："
  echo -e "  ${CYAN}fcc-claude${NC}    - 啟動 Claude Code（已接 proxy）"
  echo -e "  ${CYAN}fcc-status${NC}    - 查看 proxy 狀態"
  echo -e "  ${CYAN}fcc-log${NC}       - 看 proxy 即時 log"
  echo -e "  ${CYAN}fcc-restart${NC}   - 重啟 proxy"
  echo ""
  echo -e "  設定檔位置: ${CYAN}${FCC_ENV}${NC}"
  echo ""
  echo -e "  ${YELLOW}請重新開啟 terminal 或執行: source ~/.bashrc${NC}"
}

main "$@"
