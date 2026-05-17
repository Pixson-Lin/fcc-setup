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
MODEL_DEFAULT="nvidia_nim/z-ai/glm4.7"
MODEL_OPUS="nvidia_nim/moonshotai/kimi-k2.5"
MODEL_SONNET="nvidia_nim/z-ai/glm4.7"
MODEL_HAIKU="nvidia_nim/z-ai/glm4.7"

# Rate limit（NIM 免費層建議保持這個值）
RATE_LIMIT=1
RATE_WINDOW=3
MAX_CONCURRENCY=3

ANTHROPIC_AUTH_TOKEN="freecc"
# ─────────────────────────────────────────────────────────────────────────────

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
    local existing
    existing=$(grep "NVIDIA_NIM_API_KEY=" "$FCC_ENV" | cut -d= -f2- | tr -d '"')
    if [[ -n "$existing" && "$existing" != '""' ]]; then
      info "偵測到已有設定的 API key，跳過輸入"
      NVIDIA_NIM_API_KEY="$existing"
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
  if command -v uv &>/dev/null; then
    success "uv 已安裝 ($(uv --version))"
    uv self update 2>/dev/null || true
    return
  fi
  info "安裝 uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  if ! command -v uv &>/dev/null; then
    error "uv 安裝失敗，請手動安裝: https://docs.astral.sh/uv/"
  fi
  success "uv 安裝完成"
}

# ── Step 3: 安裝 Python 3.14 ─────────────────────────────────────────────────
install_python() {
  if uv python list 2>/dev/null | grep -q "3.14"; then
    success "Python 3.14 已安裝"
    return
  fi
  info "安裝 Python 3.14..."
  uv python install 3.14
  success "Python 3.14 安裝完成"
}

# ── Step 4: 安裝 Claude Code ─────────────────────────────────────────────────
install_claude_code() {
  if command -v claude &>/dev/null; then
    success "Claude Code 已安裝"
    return
  fi
  if ! command -v npm &>/dev/null && ! command -v node &>/dev/null; then
    warn "未偵測到 Node.js，嘗試用 nvm 安裝..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
    nvm install --lts
  fi
  info "安裝 Claude Code..."
  npm install -g @anthropic-ai/claude-code
  success "Claude Code 安裝完成"
}

# ── Step 5: 安裝 free-claude-code proxy ──────────────────────────────────────
install_fcc() {
  info "安裝 free-claude-code proxy..."
  uv tool install "git+https://github.com/Alishahryar1/free-claude-code.git" --force
  # 確保 uv tool bin 在 PATH
  local uv_bin
  uv_bin="$(uv tool dir)/../bin"
  if [[ ":$PATH:" != *":$uv_bin:"* ]]; then
    export PATH="$uv_bin:$PATH"
  fi
  success "free-claude-code 安裝完成"
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
alias fcc-log='tail -f ~/.local/share/free-claude-code/logs/fcc.log'
alias fcc-claude='ANTHROPIC_AUTH_TOKEN="freecc" ANTHROPIC_BASE_URL="http://localhost:8082" CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 claude'
# ─────────────────────────────────────────────
ALIASES
)

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
      if grep -q "free-claude-code aliases" "$rc" 2>/dev/null; then
        info "$(basename $rc) 已有 alias，跳過"
      else
        echo "$alias_block" >> "$rc"
        success "Alias 已寫入 $(basename $rc)"
      fi
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
  install_claude_code
  install_fcc
  write_config
  install_systemd_service
  write_aliases
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
