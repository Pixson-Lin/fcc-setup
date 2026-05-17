# =============================================================================
# free-claude-code 懶人安裝包 (Windows PowerShell)
# 用法:
#   直接執行: .\install.ps1
#   帶 key:   $env:NVIDIA_NIM_API_KEY="nvapi-xxx"; .\install.ps1
# 需要: PowerShell 5.1+，建議以一般使用者身份執行（不需要系統管理員）
# =============================================================================

$ErrorActionPreference = "Stop"

# ── 設定區（依需求修改這裡）──────────────────────────────────────────────────
$FCC_CONFIG_DIR = "$env:APPDATA\free-claude-code"
$FCC_ENV        = "$FCC_CONFIG_DIR\.env"
$FCC_PORT       = 8082
$FCC_LOG_DIR    = "$env:LOCALAPPDATA\free-claude-code\logs"
$SERVICE_NAME   = "FreeClaudeCodeProxy"

$MODEL_DEFAULT  = "nvidia_nim/z-ai/glm4.7"
$MODEL_OPUS     = "nvidia_nim/moonshotai/kimi-k2.5"
$MODEL_SONNET   = "nvidia_nim/z-ai/glm4.7"
$MODEL_HAIKU    = "nvidia_nim/z-ai/glm4.7"

$RATE_LIMIT         = 1
$RATE_WINDOW        = 3
$MAX_CONCURRENCY    = 3
$ANTHROPIC_AUTH_TOKEN = "freecc"
# ─────────────────────────────────────────────────────────────────────────────

function Write-Banner {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  free-claude-code 懶人安裝包 (Windows)     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# ── Step 1: 取得 API Key ─────────────────────────────────────────────────────
function Get-ApiKey {
    if ($env:NVIDIA_NIM_API_KEY) {
        Write-Info "使用環境變數中的 NVIDIA_NIM_API_KEY"
        return $env:NVIDIA_NIM_API_KEY
    }
    if (Test-Path $FCC_ENV) {
        $line = Get-Content $FCC_ENV | Where-Object { $_ -match '^NVIDIA_NIM_API_KEY=' } | Select-Object -First 1
        $existing = if ($line) { ($line -replace '^NVIDIA_NIM_API_KEY=', '').Trim().Trim('"') } else { '' }
        if ($existing -and $existing -ne "") {
            Write-Info "偵測到已有設定的 API key，跳過輸入"
            return $existing
        }
    }
    Write-Host ""
    Write-Host "請輸入 NVIDIA NIM API Key" -ForegroundColor Yellow
    Write-Host "  申請網址: https://build.nvidia.com/settings/api-keys" -ForegroundColor Cyan
    $key = Read-Host "  API Key (nvapi-...)"
    if (-not $key) { Write-Err "API Key 不能為空" }
    return $key
}

# ── Step 2: 安裝 uv ──────────────────────────────────────────────────────────
function Install-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Success "uv 已安裝"
        uv self update 2>$null
        return
    }
    Write-Info "安裝 uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Err "uv 安裝失敗，請手動安裝: https://docs.astral.sh/uv/"
    }
    Write-Success "uv 安裝完成"
}

# ── Step 3: 安裝 Python 3.14 ─────────────────────────────────────────────────
function Install-Python {
    $installed = uv python list 2>$null | Select-String "3.14"
    if ($installed) {
        Write-Success "Python 3.14 已安裝"
        return
    }
    Write-Info "安裝 Python 3.14..."
    uv python install 3.14
    Write-Success "Python 3.14 安裝完成"
}

# ── Step 4: 安裝 Claude Code ─────────────────────────────────────────────────
function Install-ClaudeCode {
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Success "Claude Code 已安裝"
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "未偵測到 Node.js，請先至 https://nodejs.org 安裝 LTS 版本後重新執行"
        Write-Err "缺少 Node.js"
    }
    Write-Info "安裝 Claude Code..."
    npm install -g @anthropic-ai/claude-code
    Write-Success "Claude Code 安裝完成"
}

# ── Step 5: 安裝 free-claude-code proxy ──────────────────────────────────────
function Install-Fcc {
    Write-Info "安裝 free-claude-code proxy..."
    uv tool install "git+https://github.com/Alishahryar1/free-claude-code.git" --force
    Write-Success "free-claude-code 安裝完成"
}

# ── Step 6: 寫入設定檔 ────────────────────────────────────────────────────────
function Write-Config {
    param($ApiKey)
    Write-Info "寫入設定檔 $FCC_ENV ..."
    New-Item -ItemType Directory -Force -Path $FCC_CONFIG_DIR | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $config = @"
# free-claude-code 設定檔
# 由安裝腳本自動產生 - $timestamp

# ── API Keys ──────────────────────────────────
NVIDIA_NIM_API_KEY="$ApiKey"
ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN"

# ── Model 路由 ────────────────────────────────
MODEL="$MODEL_DEFAULT"
MODEL_OPUS="$MODEL_OPUS"
MODEL_SONNET="$MODEL_SONNET"
MODEL_HAIKU="$MODEL_HAIKU"

# ── Rate Limit（NIM 免費層：40 req/min）───────
PROVIDER_RATE_LIMIT=$RATE_LIMIT
PROVIDER_RATE_WINDOW=$RATE_WINDOW
PROVIDER_MAX_CONCURRENCY=$MAX_CONCURRENCY

# ── Server ────────────────────────────────────
PORT=$FCC_PORT

# ── Timeouts ──────────────────────────────────
HTTP_READ_TIMEOUT=120
HTTP_WRITE_TIMEOUT=10
HTTP_CONNECT_TIMEOUT=10

# ── 其他 Provider（有需要再填）────────────────
OPENROUTER_API_KEY=""
DEEPSEEK_API_KEY=""
OLLAMA_BASE_URL="http://localhost:11434"
LM_STUDIO_BASE_URL="http://localhost:1234/v1"
"@
    Set-Content -Path $FCC_ENV -Value $config -Encoding UTF8
    Write-Success "設定檔寫入完成"
}

# ── Step 7: 安裝 Windows Task Scheduler（開機自動啟動）──────────────────────
function Install-TaskScheduler {
    param($ApiKey)
    $fccCmd = Get-Command free-claude-code -ErrorAction SilentlyContinue
    if ($fccCmd) {
        $fccBin = $fccCmd.Source
    } else {
        $fccBin = "$env:USERPROFILE\.local\bin\free-claude-code.exe"
    }

    New-Item -ItemType Directory -Force -Path $FCC_LOG_DIR | Out-Null

    # 包一個啟動用的小 wrapper script
    $wrapperPath = "$FCC_CONFIG_DIR\start-fcc.ps1"
    $wrapper = @"
# free-claude-code startup wrapper
Get-Content '$FCC_ENV' | ForEach-Object {
    `$line = `$_.Trim()
    if (`$line -and `$line[0] -ne '#') {
        `$idx = `$line.IndexOf('=')
        if (`$idx -gt 0) {
            `$name = `$line.Substring(0, `$idx).Trim()
            `$val  = `$line.Substring(`$idx + 1).Trim().Trim('"')
            [System.Environment]::SetEnvironmentVariable(`$name, `$val)
        }
    }
}
Start-Transcript -Path '$FCC_LOG_DIR\fcc.log' -Append
& '$fccBin'
"@
    Set-Content -Path $wrapperPath -Value $wrapper -Encoding UTF8

    # 移除舊的 task（若存在）
    Unregister-ScheduledTask -TaskName $SERVICE_NAME -Confirm:$false -ErrorAction SilentlyContinue

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
                 -Argument "-WindowStyle Hidden -NonInteractive -File `"$wrapperPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

    Register-ScheduledTask -TaskName $SERVICE_NAME `
        -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal `
        -Description "Free Claude Code Proxy - 開機自動啟動" | Out-Null

    # 立即啟動
    Start-ScheduledTask -TaskName $SERVICE_NAME -ErrorAction SilentlyContinue

    Write-Success "Task Scheduler 設定完成（開機自動啟動）"
}

# ── Step 8: 寫入 PowerShell Profile alias ────────────────────────────────────
function Write-Aliases {
    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
    if (-not (Test-Path $PROFILE))    { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }

    $marker = "# free-claude-code aliases"
    if (Select-String -Path $PROFILE -Pattern $marker -Quiet) {
        Write-Info "PowerShell Profile 已有 alias，跳過"
        return
    }

    $aliases = @"

$marker
function fcc-status  { Get-ScheduledTask -TaskName '$SERVICE_NAME' | Select-Object TaskName, State }
function fcc-start   { Start-ScheduledTask -TaskName '$SERVICE_NAME'; Write-Host "Proxy 已啟動" -ForegroundColor Green }
function fcc-stop    { Stop-ScheduledTask  -TaskName '$SERVICE_NAME'; Write-Host "Proxy 已停止" -ForegroundColor Yellow }
function fcc-restart { Stop-ScheduledTask  -TaskName '$SERVICE_NAME'; Start-Sleep 2; Start-ScheduledTask -TaskName '$SERVICE_NAME'; Write-Host "Proxy 已重啟" -ForegroundColor Green }
function fcc-log     { Get-Content '$FCC_LOG_DIR\fcc.log' -Tail 50 -Wait }
function fcc-claude  {
    `$env:ANTHROPIC_AUTH_TOKEN = "$ANTHROPIC_AUTH_TOKEN"
    `$env:ANTHROPIC_BASE_URL   = "http://localhost:$FCC_PORT"
    `$env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"
    claude
}
# ── end free-claude-code aliases ──
"@
    Add-Content -Path $PROFILE -Value $aliases
    Write-Success "Alias 已寫入 PowerShell Profile"
}

# ── Step 9: 驗證 ─────────────────────────────────────────────────────────────
function Test-Proxy {
    Write-Info "等待 proxy 啟動..."
    Start-Sleep -Seconds 4
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:$FCC_PORT/v1/models" `
                  -Headers @{Authorization="Bearer $ANTHROPIC_AUTH_TOKEN"} `
                  -UseBasicParsing -TimeoutSec 5
        if ($resp.StatusCode -eq 200) {
            Write-Success "Proxy 運行正常！"
        }
    } catch {
        Write-Warn "Proxy 還未回應，可能還在啟動中。請稍後執行: fcc-status"
    }
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
Write-Banner
$ApiKey = Get-ApiKey
Install-Uv
Install-Python
Install-ClaudeCode
Install-Fcc
Write-Config -ApiKey $ApiKey
Install-TaskScheduler -ApiKey $ApiKey
Write-Aliases
Test-Proxy

Write-Host ""
Write-Host "✓ 安裝完成！" -ForegroundColor Green
Write-Host ""
Write-Host "  重新開啟 PowerShell 後可使用以下指令："
Write-Host "  fcc-claude    - 啟動 Claude Code（已接 proxy）" -ForegroundColor Cyan
Write-Host "  fcc-status    - 查看 proxy 狀態" -ForegroundColor Cyan
Write-Host "  fcc-log       - 看 proxy 即時 log" -ForegroundColor Cyan
Write-Host "  fcc-restart   - 重啟 proxy" -ForegroundColor Cyan
Write-Host ""
Write-Host "  設定檔位置: $FCC_ENV" -ForegroundColor Cyan
Write-Host ""
Write-Host "  請重新開啟 PowerShell 讓 alias 生效" -ForegroundColor Yellow
