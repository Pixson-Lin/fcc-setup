# fcc-setup 專案規格說明

> 本文件供 **AI coding assistant（Cursor）與開發者**閱讀，描述產品規格與實作指引。  
> **一般使用者**安裝、操作說明請見 [README.md](../README.md)。

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

### 目前（v1.2.0）

```
fcc-setup/
├── install.sh          # Linux (Ubuntu/Debian) 安裝腳本
├── install.bat         # Windows CMD 啟動器（推薦入口；自動 Set-ExecutionPolicy 後呼叫 install.ps1）
├── install.ps1         # Windows PowerShell 安裝腳本（實際安裝邏輯）
├── LICENSE             # MIT License
├── README.md           # 使用者說明文件
└── docs/
    └── specs.md        # 本文件（AI 閱讀用）
```

### v1.3.0 預期新增

```
fcc-setup/
├── install.bat / install.ps1 / install.sh   # 安裝結束時寫入 install-manifest.json
├── uninstall.bat                            # Windows CMD 啟動器（呼叫 uninstall.ps1）
├── uninstall.ps1 / uninstall.sh             # 反安裝腳本
└── docs/specs.md
```

---

## 版本規劃

| 版本 | 狀態 | 內容 |
|------|------|------|
| v1.0.0 | 已發布 | Linux + Windows 安裝腳本，systemd + Task Scheduler |
| v1.1.0 | 已發布 | `install.bat` 啟動器、PowerShell 5.1 編碼與相容性修復 |
| v1.2.0 | 已發布 | 背景啟動 proxy、log 導向 `fcc-error.log`、`fcc-status` / `fcc-kill`、安裝穩定性 |
| **v1.3.0** | **已發布** | **同事一鍵安裝（相依性自動化、fcc 改 GitHub zip）、install manifest、反安裝腳本** |
| **v1.3.1** | **已發布** | **README 重寫與標點整理、`install.sh` 預設模型與 Windows 對齊、manifest 版號常數 1.3.1** |
| v1.4.0+ | 待定 | macOS launchd、`update.sh` / `update.ps1`（一鍵更新 fcc） |

版號格式遵循 [Semantic Versioning](https://semver.org/)。

---

## v1.3.0 — 同事一鍵安裝（相依性）

### 目標

同事無需懂 PowerShell、**git** 或 GitHub CLI（`gh`），從 **fcc-setup 的 GitHub Release** 下載安裝包後，雙擊 `install.bat` 或執行 `bash install.sh` 即可完成部署。

### 發佈與取得方式

| 角色 | 做法 |
|------|------|
| **維護者** | `git tag` + GitHub Release（**fcc-setup** repo，現行流程）；可用 `gh` 建立 repo / release |
| **同事** | 至 [fcc-setup Releases](https://github.com/Pixson-Lin/fcc-setup/releases) 下載 Source zip（**推薦**）；亦可選用 `git clone` 取得安裝腳本。**不需要**安裝 `gh`，也**不需要**為安裝 proxy 而安裝系統 `git` |

> **確認：** `install.ps1`、`install.sh`、`install.bat` 皆**未**呼叫 `gh`。`gh` 僅出現在本文件「維護者：Repo 初始化」歷史任務中。

### free-claude-code 安裝來源（調查結論）

調查 upstream [Alishahryar1/free-claude-code](https://github.com/Alishahryar1/free-claude-code)（2026-05 驗證）：

| 來源 | 結果 |
|------|------|
| **PyPI** `free-claude-code` | **無**（pypi.org 404） |
| **GitHub Releases** | **無**（`/releases` 為空） |
| **GitHub Tags** | **無** |
| **GitHub 自動 archive** | **有** — 預設分支 `main` 的 source zip |

**v1.3 採用「latest」= `main` 分支最新 commit 的 zip**（非 semver Release）。未來 upstream 若發 tag / Release，可改 URL 為 `.../archive/refs/tags/vX.Y.Z.zip`。

**下載 URL（常數，供實作）：**

```
https://github.com/Alishahryar1/free-claude-code/archive/refs/heads/main.zip
```

解壓後目錄：`free-claude-code-main/`（內含 `pyproject.toml`，目前 `version = 2.0.0`）。

**安裝（不需系統 `git`）：**

```bash
uv tool install ./free-claude-code-main --force
```

**v1.2.0 現況（將於 v1.3 廢除）：** [install.ps1](../install.ps1) / [install.sh](../install.sh) 使用 `uv tool install "git+https://github.com/Alishahryar1/free-claude-code.git"`，因此**目前**仍需要系統安裝 `git`。

### 目前安裝行為（v1.2.0 基線）

| 相依 | Windows | Linux | v1.3 變更 |
|------|---------|-------|-----------|
| uv | 自動（`irm` astral install.ps1） | 自動（`curl \| sh`） | 維持；寫入 manifest |
| Python 3.14 | 自動（`uv python install`） | 同左 | 維持；寫入 manifest |
| Node.js / npm | 僅檢查，缺失則失敗 | 同左 | **改為自動安裝** |
| free-claude-code 來源 | `git+https://...`（需系統 git） | 同左 | **改為下載 main.zip + 本機路徑安裝** |
| Claude Code CLI | 自動（`npm install -g`） | 同左 | 維持；寫入 manifest |

### v1.3 相依性自動安裝矩陣

| 相依 | 策略 |
|------|------|
| **uv** | 維持現有自動安裝；manifest 記錄 `installed_by_script: true` 與安裝路徑 |
| **Python 3.14** | 維持 `uv python install 3.14`；寫入 manifest |
| **Node.js LTS + npm** | Windows：`winget install OpenJS.NodeJS.LTS`；Linux：`sudo apt install nodejs npm`（或發行版等價套件）；**失敗時**輸出 https://nodejs.org 手動下載連結並中止，錯誤訊息可供轉貼 IT |
| **free-claude-code** | 見下方「GitHub archive 安裝流程」；**不需系統 git** |
| **Claude Code** | 維持 `npm install -g @anthropic-ai/claude-code`；manifest 記錄 |

**不納入同事安裝流程：** 系統 **git**（安裝 proxy 用）、`gh`、GitHub CLI、repo push 權限。

### GitHub archive 安裝流程（free-claude-code）

| 步驟 | Windows | Linux |
|------|---------|-------|
| 查 commit | 呼叫 GitHub API 取得 `main` 當下 SHA（見下方） | 同左 |
| 下載 | `Invoke-WebRequest` 或 `curl -fsSL` | `curl -fsSL` |
| URL | `https://github.com/Alishahryar1/free-claude-code/archive/refs/heads/main.zip` | 同左 |
| 解壓 | `Expand-Archive` 或 `tar -xf` | `unzip` 或 `tar -xf` |
| 安裝 | `uv tool install "$dir\free-claude-code-main" --force` | `uv tool install "$dir/free-claude-code-main" --force` |
| 寫 manifest | 記錄 `commit`（完整 SHA）、`ref`、`url`；可選記 `package_version`（自解壓後 `pyproject.toml`） | 同左 |
| 清理（選做） | 刪除暫存 zip / 解壓目錄以節省空間 | 同左 |

**查詢 `main` 最新 commit（不需 `gh`、不需系統 git）：**

```http
GET https://api.github.com/repos/Alishahryar1/free-claude-code/commits/main
```

回應 JSON 的 `sha` 即完整 commit（40 字元）。建議在**下載 zip 前後**各查一次；若相同則寫入 manifest，若不同（極少見）以下載後者為準並 `Write-Warn`。

manifest 欄位見 Install Manifest 章節（`commit` 為必填）。

> **v1.3 不做：** 安裝時由使用者指定 tag / commit 下載（`FCC_ARCHIVE_REF` 等設定區）——留待之後版本；目前一律 `main` zip，但以 manifest 留下實際裝到的 commit 供追蹤。

### 前置條件（無法全自動時）

- **Windows：** Windows 10+、PowerShell 5.1+、`winget`（僅用於 Node.js；缺失時改為手動安裝指引）
- **Linux：** Ubuntu / Debian 系、`curl`；`sudo`（僅 apt 安裝 node 時需要）
- **網路：** 可連 `astral.sh`、npm registry、`github.com`（下載 main.zip）、`build.nvidia.com`

### 安裝時產生的本機資源

反安裝與 manifest 必須涵蓋下列項目：

**Windows**

- `%APPDATA%\free-claude-code\.env`
- `%APPDATA%\free-claude-code\start-fcc.ps1`、`start-fcc-hidden.vbs`
- `%APPDATA%\free-claude-code\install-manifest.json`
- `%LOCALAPPDATA%\free-claude-code\logs\`
- Task Scheduler：`FreeClaudeCodeProxy`
- PowerShell Profile：`# free-claude-code aliases` … `# ── end free-claude-code aliases ──`

**Linux**

- `~/.config/free-claude-code/.env`
- `~/.config/free-claude-code/install-manifest.json`
- `~/.local/share/free-claude-code/logs/`
- systemd user unit：`free-claude-code.service`
- `loginctl enable-linger`（若腳本有執行）
- `.bashrc` / `.zshrc` alias 區塊

**跨平台（由安裝腳本管理時）**

- `uv` tool：`free-claude-code`
- `uv` 管理的 Python 3.14
- npm global：`@anthropic-ai/claude-code`
- `uv` 執行檔本身（僅當安裝前不存在、由腳本安裝時）

---

## Install Manifest（安裝紀錄）

### 路徑

| 平台 | 路徑 |
|------|------|
| Windows | `%APPDATA%\free-claude-code\install-manifest.json` |
| Linux | `~/.config/free-claude-code/install-manifest.json` |

### Schema 範例

```json
{
  "fcc_setup_version": "1.3.1",
  "installed_at": "2026-05-17T12:00:00+08:00",
  "platform": "windows",
  "items": [
    {
      "id": "uv",
      "method": "astral-installer",
      "installed_by_script": true,
      "path": "C:\\Users\\me\\.local\\bin\\uv.exe"
    },
    {
      "id": "python",
      "version": "3.14",
      "installed_by_script": true
    },
    {
      "id": "nodejs",
      "installed_by_script": true,
      "method": "winget"
    },
    {
      "id": "free-claude-code",
      "method": "github-archive",
      "ref": "main",
      "commit": "fc3ef0b5ccff880e166e8ab6789b60c1fd1f0a4f",
      "url": "https://github.com/Alishahryar1/free-claude-code/archive/refs/heads/main.zip",
      "extract_dir": "free-claude-code-main",
      "package_version": "2.0.0",
      "installed_by_script": true
    },
    {
      "id": "claude-code",
      "method": "npm-global",
      "package": "@anthropic-ai/claude-code"
    },
    {
      "id": "config",
      "path": "%APPDATA%\\free-claude-code\\.env"
    },
    {
      "id": "service",
      "type": "task-scheduler",
      "name": "FreeClaudeCodeProxy"
    },
    {
      "id": "shell-aliases",
      "target": "powershell-profile"
    }
  ]
}
```

`platform` 取值：`windows` | `linux`。  
`shell-aliases` 的 `target`：`powershell-profile` | `bashrc` | `zshrc`。

`free-claude-code`（`method: github-archive`）欄位說明：

| 欄位 | 必填 | 說明 |
|------|------|------|
| `ref` | 是 | 固定 `main`（v1.3）；日後若支援指定 ref 再擴充 |
| `commit` | 是 | 安裝當下 `main` 的完整 commit SHA（GitHub API 取得） |
| `url` | 是 | 實際下載的 archive URL |
| `extract_dir` | 建議 | 解壓後目錄名，通常 `free-claude-code-main` |
| `package_version` | 建議 | 解壓後 `pyproject.toml` 的 `version`，便於人類閱讀（與 commit 並存） |

### 規則

1. **僅記錄本次腳本實際執行的步驟。** 安裝前已存在的 uv / node 等，設 `installed_by_script: false`，反安裝時**不得**預設勾選移除。
2. 每次安裝結束**覆寫** manifest（v1.3 採覆寫；未來可選 merge 保留歷史）。
3. **`free-claude-code` 必須寫入 `commit`**，以便追查「同事機器裝的是哪一版 main」；安裝 log 建議印出 `commit` 前 7 碼與 `package_version`。
4. 安裝邏輯變更時，同步更新 manifest 寫入與 uninstall 讀取邏輯。

---

## v1.3.0 — 反安裝（Uninstall）

### 入口

| 平台 | 指令 |
|------|------|
| Windows | 雙擊 `uninstall.bat`，或 `.\uninstall.ps1` |
| Linux | `bash uninstall.sh` |

### 流程

1. 讀取 `install-manifest.json`；若不存在，提示「未偵測到安裝紀錄」並列出可手動清理路徑。
2. 停止 proxy（等同 `fcc-stop` / `Stop-Fcc`：排程、程序）。
3. 顯示摘要（項目、路徑、`installed_by_script`；`free-claude-code` 另顯示 `commit` / `package_version`）。
4. 使用者確認；**預設勾選** fcc 核心項目；**進階選項**供勾選腳本安裝的 uv / Python / Claude Code / Node。
5. 依序反向執行，輸出完成報告。

### 預設移除（fcc 核心）

使用者確認後執行：

- 停止並移除 Task Scheduler 工作 / systemd user service
- 移除 PowerShell Profile / `.bashrc` / `.zshrc` 內 alias 區塊
- 刪除設定目錄內腳本產物（`.env`、`start-fcc.ps1`、`start-fcc-hidden.vbs`、`install-manifest.json`）；**log 目錄**另詢是否刪除
- `uv tool uninstall free-claude-code`（或等價指令）

### 進階選項（互動勾選）

僅列出 manifest 中 `installed_by_script: true` 的項目，例如：

- `uv python uninstall 3.14`（若 uv 支援）
- `npm uninstall -g @anthropic-ai/claude-code`
- 移除 uv 本身（僅當由腳本安裝）

### 永不自動執行

- 還原 `Set-ExecutionPolicy`
- 刪除 `.env` 前應在摘要中**明確列出**（含 API key），建議二次確認

---

## 給 Cursor 的實作任務清單（v1.3）

請依序實作：

### Task 1：Install Manifest

- [ ] `install.ps1` / `install.sh` 安裝各步驟前後偵測「是否由腳本新安裝」
- [ ] 安裝結束寫入 `install-manifest.json`（路徑見上表）

### Task 2：相依性自動安裝與 fcc 來源

- [ ] 將 `Install-Fcc` 由 `git+https://...` 改為：GitHub API 取 `main` commit → 下載 main.zip → 解壓 → `uv tool install <本機路徑>` → manifest 寫入 `commit`
- [ ] Windows：缺 node 時嘗試 `winget`；失敗則輸出 https://nodejs.org 並 `exit 1`
- [ ] Linux：缺 node 時嘗試 `apt`（`sudo`）；失敗則輸出手動連結並 `exit 1`
- [ ] 維持 `Invoke-Native` / 錯誤處理慣例（避免 stderr info 觸發 Stop）
- [ ] **不要**再安裝或檢查系統 `git`（安裝 proxy 用）

### Task 3：反安裝腳本

- [ ] 新增 `uninstall.ps1`、`uninstall.sh`、`uninstall.bat`（結構對齊 `install.bat`）
- [ ] 讀 manifest、互動確認、預設 fcc 核心 / 進階可選移除
- [ ] 反安裝前呼叫與 `Stop-Fcc` 相同之停止邏輯

### Task 4：文件

- [ ] 更新 [README.md](../README.md)：同事從 Release 安裝、反安裝說明
- [x] [CHANGELOG.md](../CHANGELOG.md) 新增 v1.3.0 / v1.3.1 條目

### Task 5：驗證

- [ ] 乾淨 Windows VM：僅 `install.bat`，確認 node / proxy（8082）/ manifest；**無需**系統 `git`
- [ ] 執行 `uninstall.bat`，確認預設移除後 8082 無監聽、alias 已清

---

## 維護者：Repo 初始化（已完成）

> 以下為專案建立時一次性任務，**同事安裝不需要執行**。

### Task 1：初始化 Git repo

```bash
git init
git add .
git commit -m "feat: initial release - cross-platform fcc-setup installer"
```

### Task 2：建立 GitHub remote repo

使用 GitHub CLI（`gh`）建立 public repo 並推上去：

```bash
gh auth login
gh repo create fcc-setup \
  --public \
  --description "One-liner installer for free-claude-code proxy (NVIDIA NIM + Claude Code)" \
  --source=. \
  --remote=origin \
  --push
```

若無 `gh`：至 https://github.com/new 手動建立 repo 後：

```bash
git remote add origin https://github.com/使用者名稱/fcc-setup.git
git branch -M main
git push -u origin main
```

### Task 3：建立 .gitignore

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
gh repo edit --add-topic "claude-code,nvidia-nim,ai-tools,installer,free-llm"
```

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
- `install.bat` / `uninstall.bat` 僅為 Windows CMD 啟動器，不含設定區；邏輯在對應 `.ps1`
- Windows 使用者建議執行 `install.bat`（雙擊即可），無需了解 PowerShell 或手動 `Set-ExecutionPolicy`
- API key 永遠不應該 hardcode 進腳本或 commit 進 repo
- script 設計為冪等（idempotent）——重複執行不會壞掉
- v1.3 起：安裝必須寫 manifest；反安裝必須讀 manifest；兩者邏輯需同步維護
- 反安裝前必須先停止 proxy（排程 + `free-claude-code` 程序），避免檔案鎖定
- **free-claude-code 安裝：** v1.3 使用 GitHub `main` zip，**不需**系統 git；每次安裝可能不同 commit，**須寫入 manifest 的 `commit` 欄位**（GitHub REST API，不需 `gh`）
- **日後再做：** 設定區 `FCC_ARCHIVE_REF` 讓維護者指定 tag / commit 下載（v1.3 一律 latest `main`）
- upstream 尚無 GitHub Release 時，無法使用 `releases/latest` API，須固定 `refs/heads/main`（或日後改 tag URL）
