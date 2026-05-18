# free-claude-code 懶人安裝包

## 如果你連說明都不想看

1. 跟認識的人**借**一個 NVIDIA NIM API Key（但請勿再轉借他人，也不要公開）
2. 下載 [fcc-setup Releases](https://github.com/Pixson-Lin/fcc-setup/releases) 然後解壓縮
3. 點兩下 `install.bat` 然後被要求的時候把 Key 貼上去
4. 開一個新的 PowerShell 視窗（非平常的 CMD）然後輸入 `fcc-claude`
5. 開始用免費版 Claude Code

過程應該不用 15 分鐘，試試看吧！

---

## 什麼是 free-claude-code 懶人安裝包

快速在多台機器上部署 `free-claude-code` proxy，讓你用 NVIDIA NIM 或 OpenRouter 等服務免費跑 Claude Code。

### 什麼是 `free-claude-code` proxy

[free-claude-code](https://github.com/Alishahryar1/free-claude-code) 是一套在本機執行的 **Anthropic 相容 proxy**：Claude Code（終端機 CLI、VS Code、JetBrains ACP 等）仍用原本的協定，但 API 流量會改走你設定的後端，而不必綁定 Anthropic 官方訂閱。

它提供：

- **Drop-in 代理**：承接 Claude Code 的 Anthropic Messages API 呼叫
- **多種 provider**：NVIDIA NIM、Kimi、OpenRouter、DeepSeek、Ollama、LM Studio 等
- **分級路由**：`MODEL` / `MODEL_OPUS` / `MODEL_SONNET` / `MODEL_HAIKU` 可指向不同模型
- **完整工作流**：串流、tool use、reasoning blocks；本機 **Admin UI**（`/admin`）可改設定與驗證 provider

## 那為什麼你還要來這裡

因為 `free-claude-code` 安裝還是需要一點工，來這裡可以更懶人一點。

**fcc-setup（本 repo）** 不 fork 上游程式，而是懶人安裝包：一鍵用大眾（其實是作者本人）喜好幫你裝好 proxy、Claude Code、`.env` 與開機自動啟動，預設接 NVIDIA NIM 免費額度。

---

## 同事一鍵安裝（v1.3）

0. 去 [NVIDIA NIM](https://build.nvidia.com/settings/api-keys) 申請你私人的 API Key（如果覺得很難，見下方 [超級詳盡說明](#nvidia-nim-api-key-申請的超級詳盡說明)；真的很難可先用借的，但請勿公開、勿轉借）
1. 至 [fcc-setup Releases](https://github.com/Pixson-Lin/fcc-setup/releases) 下載 **Source code (zip)** 或 **.tar.gz**（Linux）
2. 解壓後進入資料夾
3. **Windows：** 點兩下 `install.bat`（不需安裝 git、不需懂 PowerShell）
4. **Linux：** `bash install.sh`（需 `curl`、`sudo` 僅在自動安裝 Node 時使用）

安裝結束會寫入 `install-manifest.json`，記錄各元件是否由腳本安裝，以及 proxy 對應的 upstream **commit**。

**反安裝：** 點兩下 `uninstall.bat`（Windows）或執行 `bash uninstall.sh`（Linux）。預設移除 proxy、設定、排程與 alias；進階選項可移除腳本當初安裝的 uv / Python / Claude Code 等。

## 安裝後可用指令

| 指令 | 說明 |
|------|------|
| `fcc-claude` | 啟動 Claude Code（已自動接上 proxy） |
| `fcc-status` | 查看 proxy 狀態 |
| `fcc-start` | 啟動 proxy |
| `fcc-stop` | 停止 proxy |
| `fcc-restart` | 重啟 proxy |
| `fcc-log` | 即時查看 log |

---

## 完整使用方式

### Windows

**推薦：直接執行 `install.bat`**（雙擊或在 CMD 執行，不需認識 PowerShell；會自動設定執行原則並呼叫 `install.ps1`）

```bat
REM 方式一：帶 API key 直接執行（推薦，不用互動輸入）
set NVIDIA_NIM_API_KEY=nvapi-你的key && install.bat

REM 方式二：互動輸入 key
install.bat
```

若你熟悉 PowerShell，也可直接執行 `install.ps1`：

```powershell
# 方式一：帶 API key 直接執行（推薦）
$env:NVIDIA_NIM_API_KEY="nvapi-你的key"; .\install.ps1

# 方式二：互動輸入 key
.\install.ps1
```

> 使用 `install.bat` 時無需手動執行 `Set-ExecutionPolicy`；直接執行 `install.ps1` 時，第一次可能需要：
> `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Linux

```bash
# 方式一：帶 API key 直接執行（推薦，不用互動輸入）
NVIDIA_NIM_API_KEY="nvapi-你的key" bash install.sh

# 方式二：互動輸入 key
bash install.sh
```

---

## 設定檔位置

| 系統 | 路徑 |
|------|------|
| Linux | `~/.config/free-claude-code/.env` |
| Windows | `%APPDATA%\free-claude-code\.env` |

安裝紀錄（反安裝用）：同目錄下的 `install-manifest.json`。

想換模型或調整設定，直接編輯 `.env` 後執行 `fcc-restart`。

---

## Log 位置

| 系統 | stdout | stderr |
|------|--------|--------|
| Linux | `~/.local/share/free-claude-code/logs/fcc.log` | `.../fcc-error.log` |
| Windows | `%LOCALAPPDATA%\free-claude-code\logs\fcc.log` | `.../fcc-error.log` |

`fcc-log` 會先列出 log 路徑、顯示各檔最近 100 行，再即時追蹤（Ctrl+C 結束）。

---

## 自動啟動機制

| 系統 | 方式 |
|------|------|
| Linux | systemd user service（`~/.config/systemd/user/free-claude-code.service`） |
| Windows | Task Scheduler（登入時自動執行） |

---

## 常用模型（NIM 免費層）

```env
MODEL="nvidia_nim/mistralai/mistral-nemotron"              # 預設
MODEL_OPUS="nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct" # 重任務
MODEL_SONNET="nvidia_nim/mistralai/mistral-nemotron"       # 中等任務
MODEL_HAIKU="nvidia_nim/stepfun-ai/step-3.5-flash"         # 輕任務
```

可至 [build.nvidia.com](https://build.nvidia.com/explore/discover) 查看所有可用模型，勾選 Free Endpoints，再按 Apply 篩選，可以挑出免費的。

---

## NVIDIA NIM API Key 申請的超級詳盡說明

1. 前往 [build.nvidia.com/settings/api-keys](https://build.nvidia.com/settings/api-keys)
2. 用 Google 或 GitHub 登入
3. 點 **Get API Key**
4. 複製 `nvapi-` 開頭的 key

免費額度：40 req/min

---

## 檔案說明

```
fcc-setup/
├── install.sh       # Linux (Ubuntu/Debian) 安裝腳本
├── install.bat      # Windows CMD 啟動器（推薦，雙擊即可）
├── install.ps1      # Windows PowerShell 安裝腳本（實際安裝邏輯）
├── uninstall.sh     # Linux 反安裝
├── uninstall.bat    # Windows CMD 反安裝啟動器
├── uninstall.ps1    # Windows 反安裝邏輯
└── README.md        # 本說明
```
