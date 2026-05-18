# Changelog

所有重要變更都會記錄在這裡。格式依照 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)，版號遵循 [Semantic Versioning](https://semver.org/)。

---

## [1.2.0] - 2026-05-17

### Added
- Windows：已有 API key 時提示遮罩預覽，可 Enter 沿用或輸入新 key
- Windows：`fcc-kill`、`fcc-status` 增加 port / API 健康檢查
- Windows：Profile alias 支援自動更新（重跑安裝會覆寫舊版函式）
- `README.md`：補充 log 路徑說明（`fcc.log` / `fcc-error.log`）

### Fixed
- `install.bat`：改為純 ASCII，避免 CMD 解析 UTF-8 中文失敗
- `install.ps1`：`uv` 的 stderr info 不再觸發 `$ErrorActionPreference Stop` 中斷安裝
- `install.ps1`：安裝 fcc 前自動停止殘留程序，避免 `uv tool install` 存取被拒
- `install.ps1`：修正背景啟動（改直接 `Start-Process`，不再用無效的 `cmd >>` 包裝）
- `install.ps1`：`.env` 改以 `$env:` 注入，proxy 可正常讀取 API key
- `install.ps1`：log 正確導向 `fcc-error.log`（uvicorn 主輸出）

### Changed
- `install.sh`：已有 API key 時改為互動確認（與 Windows 一致）

---

## [1.1.0] - 2026-05-17

### Added
- `install.bat`：Windows CMD 啟動器，雙擊即可安裝，自動設定執行原則並呼叫 `install.ps1`

### Fixed
- `install.ps1`：修正 UTF-8 無 BOM 導致 PowerShell 5.1 無法解析中文的問題
- `install.ps1`：移除 PowerShell 7 專用語法（`?.`），改寫 API key 讀取邏輯

### Changed
- `README.md`、`docs/specs.md`：補充 `install.bat` 使用說明

---

## [1.0.0] - 2026-05-17

### Added
- `install.sh`：Linux (Ubuntu/Debian) 一鍵安裝腳本
  - 自動安裝 uv、Python 3.14、Claude Code、free-claude-code
  - systemd user service（開機自動啟動，不需要 root）
  - alias 寫入 `.bashrc` / `.zshrc`
- `install.ps1`：Windows PowerShell 一鍵安裝腳本
  - Task Scheduler 開機自動啟動
  - alias 寫入 PowerShell Profile
- 支援環境變數傳入 API key（`NVIDIA_NIM_API_KEY=xxx bash install.sh`）
- 冪等設計：重複執行不會壞掉
- Per-tier model routing（Opus / Sonnet / Haiku 可分別指定不同模型）
