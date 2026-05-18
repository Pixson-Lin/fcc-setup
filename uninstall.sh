#!/usr/bin/env bash
# =============================================================================
# free-claude-code 反安裝腳本 (Linux)
# 用法: bash uninstall.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

FCC_CONFIG_DIR="$HOME/.config/free-claude-code"
FCC_ENV="$FCC_CONFIG_DIR/.env"
FCC_LOG_DIR="$HOME/.local/share/free-claude-code/logs"
FCC_MANIFEST="$FCC_CONFIG_DIR/install-manifest.json"
SERVICE_NAME="free-claude-code"

stop_fcc() {
  systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
  pkill -f 'free-claude-code' 2>/dev/null || true
  sleep 2
}

show_manual_paths() {
  echo ""
  echo -e "${YELLOW}可手動清理的路徑：${NC}"
  echo "  $FCC_CONFIG_DIR"
  echo "  $FCC_LOG_DIR"
  echo "  ~/.config/systemd/user/${SERVICE_NAME}.service"
  echo "  ~/.bashrc / ~/.zshrc 內 free-claude-code aliases 區塊"
  echo ""
}

manifest_item_installed_by_script() {
  local id="$1"
  [[ -f "$FCC_MANIFEST" ]] || return 1
  grep -q "\"id\":\"$id\"" "$FCC_MANIFEST" && \
    grep -A5 "\"id\":\"$id\"" "$FCC_MANIFEST" | grep -q '"installed_by_script":true'
}

remove_shell_aliases() {
  local rc marker_start marker_end
  marker_start='# ── free-claude-code aliases'
  marker_end='# ─────────────────────────────────────────────'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$rc" ]] || continue
    if grep -q "free-claude-code aliases" "$rc" 2>/dev/null; then
      sed -i "/${marker_start}/,/${marker_end}/d" "$rc" 2>/dev/null || \
        sed -i '' "/${marker_start}/,/${marker_end}/d" "$rc" 2>/dev/null || true
      success "已移除 $(basename "$rc") alias 區塊"
    fi
  done
}

remove_core() {
  stop_fcc

  local service_file="$HOME/.config/systemd/user/${SERVICE_NAME}.service"
  if [[ -f "$service_file" ]]; then
    systemctl --user daemon-reload 2>/dev/null || true
    rm -f "$service_file"
    systemctl --user daemon-reload 2>/dev/null || true
    info "已移除 systemd user service"
  fi

  remove_shell_aliases

  if command -v uv &>/dev/null; then
    info "移除 uv tool: free-claude-code..."
    uv tool uninstall free-claude-code 2>/dev/null || true
  fi

  rm -f "$FCC_ENV" "$FCC_MANIFEST" 2>/dev/null || true
  rmdir "$FCC_CONFIG_DIR" 2>/dev/null || true
}

remove_advanced() {
  local ids="$1"
  local id
  for id in $ids; do
    manifest_item_installed_by_script "$id" || continue
    case "$id" in
      python)
        if command -v uv &>/dev/null; then
          info "移除 Python 3.14 (uv)..."
          uv python uninstall 3.14 2>/dev/null || true
        fi
        ;;
      claude-code)
        if command -v npm &>/dev/null; then
          info "移除 Claude Code (npm global)..."
          npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
        fi
        ;;
      uv)
        local uv_path
        uv_path="$(command -v uv 2>/dev/null || true)"
        if [[ -n "$uv_path" && -f "$uv_path" ]]; then
          info "移除 uv ($uv_path)..."
          rm -f "$uv_path"
        fi
        ;;
      nodejs)
        warn "Node.js 請使用: sudo apt remove nodejs npm"
        ;;
    esac
  done
}

echo ""
echo -e "${CYAN}free-claude-code 反安裝${NC}"
echo ""

if [[ -f "$FCC_MANIFEST" ]]; then
  info "讀取安裝紀錄: $FCC_MANIFEST"
else
  warn "未偵測到安裝紀錄 ($FCC_MANIFEST)"
  show_manual_paths
  read -r -p "仍要嘗試清理 fcc 核心項目？(y/N) " cont
  [[ "$cont" =~ ^[yY]$ ]] || exit 0
fi

echo ""
echo -e "${YELLOW}── 將移除（fcc 核心，預設）──${NC}"
echo "  systemd user service: $SERVICE_NAME"
echo "  uv tool uninstall free-claude-code"
echo -e "  設定檔: $FCC_ENV ${YELLOW}（含 API key）${NC}"
echo "  install-manifest.json"
echo "  shell alias 區塊"
if [[ -f "$FCC_MANIFEST" ]]; then
  commit=$(grep -o '"commit":"[a-f0-9]*"' "$FCC_MANIFEST" | head -1 | cut -d'"' -f4 || true)
  if [[ -n "$commit" ]]; then
    echo "  已安裝 proxy commit: ${commit:0:7}"
  fi
fi
echo ""

read -r -p "確認移除 fcc 核心項目？(y/N) " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { info "已取消"; exit 0; }

advanced_list=""
for candidate in uv python nodejs claude-code; do
  if manifest_item_installed_by_script "$candidate"; then
    advanced_list="$advanced_list $candidate"
  fi
done

remove_advanced_ids=""
if [[ -n "$advanced_list" ]]; then
  echo ""
  echo -e "${YELLOW}── 進階選項（installed_by_script: true）──${NC}"
  echo "$advanced_list"
  echo ""
  read -r -p "一併移除？輸入逗號分隔 id 或 Enter 跳過: " adv
  remove_advanced_ids="${adv//,/ }"
fi

read -r -p "是否刪除 log 目錄 $FCC_LOG_DIR ？(y/N) " delete_logs

remove_core
if [[ -n "$remove_advanced_ids" ]]; then
  remove_advanced "$remove_advanced_ids"
fi
if [[ "$delete_logs" =~ ^[yY]$ && -d "$FCC_LOG_DIR" ]]; then
  rm -rf "$(dirname "$FCC_LOG_DIR")"
  success "已刪除 log 目錄"
fi

echo ""
success "反安裝完成"
echo ""
