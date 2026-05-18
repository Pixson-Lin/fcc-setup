# free-claude-code 懶人安裝包

快速在多台機器上部署 `free-claude-code` proxy，讓你用 NVIDIA NIM 免費跑 Claude Code。

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

## 同事一鍵安裝（v1.3）

1. 至 [fcc-setup Releases](https://github.com/Pixson-Lin/fcc-setup/releases) 下載 **Source code (zip)**
2. 解壓後進入資料夾
3. **Windows：** 雙擊 `install.bat`（不需安裝 git、不需懂 PowerShell）
4. **Linux：** `bash install.sh`（需 `curl`、`sudo` 僅在自動安裝 Node 時使用）

安裝結束會寫入 `install-manifest.json`，記錄各元件是否由腳本安裝，以及 proxy 對應的 upstream **commit**。

**反安裝：** 雙擊 `uninstall.bat`（Windows）或 `bash uninstall.sh`（Linux）。預設移除 proxy、設定、排程與 alias；進階選項可移除腳本當初安裝的 uv / Python / Claude Code 等。

## 使用方式

### Linux

```bash
# 方式一：帶 API key 直接執行（推薦，不用互動輸入）
NVIDIA_NIM_API_KEY="nvapi-你的key" bash install.sh

# 方式二：互動輸入 key
bash install.sh
```

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

---

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
MODEL="nvidia_nim/z-ai/glm4.7"                  # 預設，綜合表現好
MODEL_OPUS="nvidia_nim/moonshotai/kimi-k2.5"    # 重任務
MODEL_SONNET="nvidia_nim/z-ai/glm4.7"           # 中等任務
MODEL_HAIKU="nvidia_nim/z-ai/glm4.7"            # 輕任務
```

可至 [build.nvidia.com](https://build.nvidia.com/explore/discover) 查看所有可用模型。

---

## API Key 申請

1. 前往 <https://build.nvidia.com/settings/api-keys>
2. 用 Google 或 GitHub 登入
3. 點 **Get API Key**
4. 複製 `nvapi-` 開頭的 key

免費額度：40 req/min
