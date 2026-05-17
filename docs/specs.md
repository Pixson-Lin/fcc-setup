# fcc-setup 專案規格說明

> 本文件供 AI coding assistant（Cursor）閱讀，用於協助完成 GitHub 初始化與版控設定。

---

## 專案概述

**fcc-setup** 是一個跨平台懶人安裝腳本集合，目的是讓使用者可以一行指令在多台機器上部署 [free-claude-code](https://github.com/Alishahryar1/free-claude-code) proxy，透過 NVIDIA NIM 免費使用 Claude Code CLI。

### 核心概念

```
Claude Code CLI
    ↓ 以為在打 Anthropic API
free-claude-code proxy (localhost:8082)
    ↓ 格式轉換
NVIDIA NIM / OpenRouter / Ollama 等免費後端
```

---

## 專案結構

```
fcc-setup/
├── install.sh          # Linux (Ubuntu/Debian) 安裝腳本
├── install.ps1         # Windows PowerShell 安裝腳本
├── LICENSE             # MIT License
├── README.md           # 使用者說明文件
└── docs/
    └── specs.md        # 本文件（AI 閱讀用）
```

---

## 給 Cursor 的任務清單

請依序完成以下任務：

### Task 1：初始化 Git repo

```bash
git init
git add .
git commit -m "feat: initial release - cross-platform fcc-setup installer"
```

### Task 2：建立 GitHub remote repo

使用 GitHub CLI（`gh`）建立 public repo 並推上去：

```bash
# 如果還沒登入
gh auth login

# 建立 repo 並推送
gh repo create fcc-setup \
  --public \
  --description "One-liner installer for free-claude-code proxy (NVIDIA NIM + Claude Code)" \
  --source=. \
  --remote=origin \
  --push
```

如果使用者沒有 `gh`，改用以下流程並提示使用者：
1. 前往 https://github.com/new 手動建立 repo，名稱建議 `fcc-setup`
2. 然後執行：
```bash
git remote add origin https://github.com/使用者名稱/fcc-setup.git
git branch -M main
git push -u origin main
```

### Task 3：建立 .gitignore

建立 `.gitignore`，確保以下內容不被 commit：

```gitignore
# 絕對不能上傳的
.env
*.env
**/apkey.cfg
**/.env

# 系統檔
.DS_Store
Thumbs.db
desktop.ini

# Log
*.log
logs/

# Python
__pycache__/
*.pyc
.venv/

# Node
node_modules/
```

### Task 4：設定 GitHub repo 基本資訊（選做）

```bash
# 加上 topics 讓人比較容易找到
gh repo edit --add-topic "claude-code,nvidia-nim,ai-tools,installer,free-llm"
```

---

## 版本規劃（供未來參考）

| 版本 | 內容 |
|------|------|
| v1.0.0 | Linux + Windows 安裝腳本，systemd + Task Scheduler |
| v1.1.0 | 新增 macOS launchd 支援 |
| v1.2.0 | 新增 update.sh / update.ps1（一鍵更新 fcc） |

版號格式遵循 [Semantic Versioning](https://semver.org/)。

---

## 重要相依專案

| 專案 | 用途 | 連結 |
|------|------|------|
| free-claude-code | 核心 proxy | https://github.com/Alishahryar1/free-claude-code |
| Claude Code | AI coding CLI | https://github.com/anthropics/claude-code |
| NVIDIA NIM | 免費 LLM API 後端 | https://build.nvidia.com |
| uv | Python 套件管理 | https://docs.astral.sh/uv |

---

## 注意事項

- `install.sh` 和 `install.ps1` 裡有一個「設定區」section，修改時只改那個區塊
- API key 永遠不應該 hardcode 進腳本或 commit 進 repo
- script 設計為冪等（idempotent）——重複執行不會壞掉
