# Changelog

所有重要變更都會記錄在這裡。格式依照 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)，版號遵循 [Semantic Versioning](https://semver.org/)。

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
