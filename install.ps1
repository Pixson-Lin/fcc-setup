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

$MODEL_DEFAULT  = "nvidia_nim/mistralai/mistral-nemotron"
$MODEL_OPUS     = "nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct"
$MODEL_SONNET   = "nvidia_nim/mistralai/mistral-nemotron"
$MODEL_HAIKU    = "nvidia_nim/stepfun-ai/step-3.5-flash"

$RATE_LIMIT         = 1
$RATE_WINDOW        = 3
$MAX_CONCURRENCY    = 3
$ANTHROPIC_AUTH_TOKEN = "freecc"

$FCC_SETUP_VERSION  = "1.3.0"
$FCC_MANIFEST       = "$FCC_CONFIG_DIR\install-manifest.json"
$FCC_ARCHIVE_URL    = "https://github.com/Alishahryar1/free-claude-code/archive/refs/heads/main.zip"
$FCC_API_COMMITS    = "https://api.github.com/repos/Alishahryar1/free-claude-code/commits/main"
$FCC_EXTRACT_DIR    = "free-claude-code-main"
# ─────────────────────────────────────────────────────────────────────────────

$script:ManifestItems = @()
$script:FccArchiveMeta = $null

function Add-ManifestItem {
    param([hashtable]$Item)
    $script:ManifestItems += [PSCustomObject]$Item
}

function Write-Manifest {
    New-Item -ItemType Directory -Force -Path $FCC_CONFIG_DIR | Out-Null
    $manifest = [ordered]@{
        fcc_setup_version = $FCC_SETUP_VERSION
        installed_at      = (Get-Date).ToString("o")
        platform          = "windows"
        items             = $script:ManifestItems
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $FCC_MANIFEST -Encoding UTF8
    Write-Success "安裝紀錄已寫入 $FCC_MANIFEST"
}

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

# 外部指令常把 info 寫到 stderr；在 Stop 模式下需避免被當成 terminating error
function Invoke-Native {
    param(
        [scriptblock]$Command,
        [switch]$Quiet
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Quiet) { & $Command 2>&1 | Out-Null } else { & $Command 2>&1 }
    } finally {
        $ErrorActionPreference = $prev
    }
}

# ── Step 1: 取得 API Key ─────────────────────────────────────────────────────
function Show-ApiKeyPrompt {
    Write-Host ""
    Write-Host "請輸入 NVIDIA NIM API Key" -ForegroundColor Yellow
    Write-Host "  申請網址: https://build.nvidia.com/settings/api-keys" -ForegroundColor Cyan
}

function Mask-ApiKey {
    param([string]$Key)
    if ($Key.Length -le 12) { return "***" }
    return $Key.Substring(0, 8) + "..." + $Key.Substring($Key.Length - 4)
}

function Get-ApiKey {
    if ($env:NVIDIA_NIM_API_KEY) {
        Write-Info "使用環境變數中的 NVIDIA_NIM_API_KEY"
        return $env:NVIDIA_NIM_API_KEY
    }
    if (Test-Path $FCC_ENV) {
        $line = Get-Content $FCC_ENV | Where-Object { $_ -match '^NVIDIA_NIM_API_KEY=' } | Select-Object -First 1
        $existing = if ($line) { ($line -replace '^NVIDIA_NIM_API_KEY=', '').Trim().Trim('"') } else { '' }
        if ($existing -and $existing -ne "") {
            Write-Host ""
            Write-Host "偵測到已有 API key：$(Mask-ApiKey $existing)" -ForegroundColor Yellow
            Write-Host "  按 Enter 沿用，或輸入新 key 覆蓋" -ForegroundColor Cyan
            $key = Read-Host "  API Key (nvapi-...)"
            if ($key) { return $key }
            Write-Info "沿用既有 API key"
            return $existing
        }
    }
    Show-ApiKeyPrompt
    $key = Read-Host "  API Key (nvapi-...)"
    if (-not $key) { Write-Err "API Key 不能為空" }
    return $key
}

# ── Step 2: 安裝 uv ──────────────────────────────────────────────────────────
function Install-Uv {
    $existed = [bool](Get-Command uv -ErrorAction SilentlyContinue)
    if ($existed) {
        Write-Success "uv 已安裝"
        Invoke-Native { uv self update } -Quiet
    } else {
        Write-Info "安裝 uv..."
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            Write-Err "uv 安裝失敗，請手動安裝: https://docs.astral.sh/uv/"
        }
        Write-Success "uv 安裝完成"
    }
    $uvPath = (Get-Command uv -ErrorAction SilentlyContinue).Source
    Add-ManifestItem @{
        id                   = "uv"
        method               = "astral-installer"
        installed_by_script  = (-not $existed)
        path                 = $uvPath
    }
}

# ── Step 3: 安裝 Python 3.14 ─────────────────────────────────────────────────
function Install-Python {
    $had314 = [bool](Invoke-Native { uv python list } | Select-String "3.14")
    if ($had314) {
        Write-Success "Python 3.14 已安裝"
    } else {
        Write-Info "安裝 Python 3.14..."
        Invoke-Native { uv python install 3.14 }
        if ($LASTEXITCODE -ne 0) { Write-Err "Python 3.14 安裝失敗" }
        Write-Success "Python 3.14 安裝完成"
    }
    Add-ManifestItem @{
        id                  = "python"
        version             = "3.14"
        installed_by_script = (-not $had314)
    }
}

# ── Step 3b: 安裝 Node.js ────────────────────────────────────────────────────
function Install-Node {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Success "Node.js 已安裝"
        Add-ManifestItem @{ id = "nodejs"; installed_by_script = $false; method = "existing" }
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err @"
未找到 winget，無法自動安裝 Node.js。
請至 https://nodejs.org 下載安裝 LTS 後重新執行 install.bat
"@
    }
    Write-Info "安裝 Node.js LTS (winget)..."
    Invoke-Native {
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Err @"
Node.js 安裝失敗。
請至 https://nodejs.org 下載安裝 LTS 後重新執行 install.bat
"@
    }
    Write-Success "Node.js 安裝完成"
    Add-ManifestItem @{ id = "nodejs"; installed_by_script = $true; method = "winget" }
}

# ── Step 4: 安裝 Claude Code ─────────────────────────────────────────────────
function Install-ClaudeCode {
    $hadClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
    if ($hadClaude) {
        Write-Success "Claude Code 已安裝"
    } else {
        Write-Info "安裝 Claude Code..."
        npm install -g @anthropic-ai/claude-code
        Write-Success "Claude Code 安裝完成"
    }
    Add-ManifestItem @{
        id                  = "claude-code"
        method              = "npm-global"
        package             = "@anthropic-ai/claude-code"
        installed_by_script = (-not $hadClaude)
    }
}

# ── Step 5: 安裝 free-claude-code proxy ──────────────────────────────────────
function Stop-Fcc {
    Write-Info "停止既有 free-claude-code 程序（避免 uv 更新時檔案被鎖定）..."
    Stop-ScheduledTask -TaskName $SERVICE_NAME -ErrorAction SilentlyContinue

    @('free-claude-code', 'fcc-server') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*free-claude-code*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Start-Sleep -Seconds 2
}

function Get-FccMainCommit {
    $headers = @{ "User-Agent" = "fcc-setup/$FCC_SETUP_VERSION" }
    try {
        $resp = Invoke-RestMethod -Uri $FCC_API_COMMITS -Headers $headers -UseBasicParsing
        return $resp.sha
    } catch {
        Write-Warn "無法連線 GitHub API（$($_.Exception.Message)），略過 commit 查詢"
        return $null
    }
}

function Get-FccPackageVersion {
    param([string]$SrcDir)
    $pyproject = Join-Path $SrcDir "pyproject.toml"
    if (-not (Test-Path $pyproject)) { return $null }
    $m = Select-String -Path $pyproject -Pattern '^\s*version\s*=\s*"([^"]+)"' | Select-Object -First 1
    if ($m) { return $m.Matches.Groups[1].Value }
    return $null
}

function Install-FccFromArchive {
    param([string]$SrcDir)
    Invoke-Native { uv tool install $SrcDir --force }
}

function Install-Fcc {
    Stop-Fcc

    $commitBefore = Get-FccMainCommit
    $tmpdir = Join-Path $env:TEMP "fcc-setup-fcc-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $zipPath = Join-Path $tmpdir "main.zip"
    $extractRoot = Join-Path $tmpdir "extract"
    New-Item -ItemType Directory -Force -Path $tmpdir | Out-Null

    Write-Info "下載 free-claude-code (main)..."
    try {
        Invoke-WebRequest -Uri $FCC_ARCHIVE_URL -OutFile $zipPath -UseBasicParsing
    } catch {
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Err "無法下載 main.zip（$($_.Exception.Message)）。請確認可連線 github.com 後重試。"
    }

    $commitAfter = Get-FccMainCommit
    if ($commitAfter -and $commitBefore -and $commitAfter -ne $commitBefore) {
        Write-Warn "main 分支 commit 在下載期間變動，使用下載後 commit: $($commitAfter.Substring(0, 7))"
        $commit = $commitAfter
    } elseif ($commitAfter) {
        $commit = $commitAfter
    } elseif ($commitBefore) {
        $commit = $commitBefore
    } else {
        $commit = "unknown"
        Write-Warn "未能取得 commit SHA，manifest 將記錄為 unknown"
    }

    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
    $srcDir = Join-Path $extractRoot $FCC_EXTRACT_DIR
    if (-not (Test-Path $srcDir)) {
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Err "解壓後找不到目錄 $FCC_EXTRACT_DIR"
    }

    $pkgVersion = Get-FccPackageVersion $srcDir
    $shortSha = if ($commit -eq "unknown") { "unknown" } else { $commit.Substring(0, [Math]::Min(7, $commit.Length)) }
    if ($pkgVersion) {
        Write-Info "安裝 free-claude-code ($shortSha, v$pkgVersion)..."
    } else {
        Write-Info "安裝 free-claude-code ($shortSha)..."
    }

    Install-FccFromArchive $srcDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "安裝受阻，再次停止程序後重試..."
        Stop-Fcc
        Start-Sleep -Seconds 3
        Install-FccFromArchive $srcDir
    }
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Err @"
free-claude-code 安裝失敗（常見原因：程序仍佔用檔案）。
請先：
  1. 關閉所有 PowerShell / CMD 視窗
  2. 工作管理員結束 free-claude-code、python（路徑含 free-claude-code）
  3. 再執行 install.bat
"@
    }

    $script:FccArchiveMeta = @{
        method           = "github-archive"
        ref              = "main"
        commit           = $commit
        url              = $FCC_ARCHIVE_URL
        extract_dir      = $FCC_EXTRACT_DIR
        package_version  = $pkgVersion
    }

    Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
    if ($pkgVersion) {
        Write-Success "free-claude-code 安裝完成 ($shortSha, v$pkgVersion)"
    } else {
        Write-Success "free-claude-code 安裝完成 ($shortSha)"
    }

    Add-ManifestItem @{
        id                  = "free-claude-code"
        method              = "github-archive"
        ref                 = "main"
        commit              = $commit
        url                 = $FCC_ARCHIVE_URL
        extract_dir         = $FCC_EXTRACT_DIR
        package_version     = $pkgVersion
        installed_by_script = $true
    }
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

    # 啟動 wrapper：載入 .env 後以背景行程啟動 proxy（不佔用終端機視窗）
    $wrapperPath = "$FCC_CONFIG_DIR\start-fcc.ps1"
    $vbsPath     = "$FCC_CONFIG_DIR\start-fcc-hidden.vbs"
    $wrapper = @"
# free-claude-code startup wrapper (background)
`$logPath = '$FCC_LOG_DIR\fcc.log'
`$errPath = '$FCC_LOG_DIR\fcc-error.log'
Get-Content '$FCC_ENV' | ForEach-Object {
    `$line = `$_.Trim()
    if (`$line -and `$line[0] -ne '#') {
        `$idx = `$line.IndexOf('=')
        if (`$idx -gt 0) {
            `$name = `$line.Substring(0, `$idx).Trim()
            `$val  = `$line.Substring(`$idx + 1).Trim().Trim('"')
            Set-Item -Path "env:`$name" -Value `$val
        }
    }
}
"[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting free-claude-code" | Out-File -FilePath `$logPath -Append -Encoding utf8
`$fcc = '$fccBin'
Start-Process -FilePath `$fcc -WindowStyle Hidden `
    -WorkingDirectory (Split-Path `$fcc -Parent) `
    -RedirectStandardOutput `$logPath -RedirectStandardError `$errPath
"@
    Set-Content -Path $wrapperPath -Value $wrapper -Encoding UTF8

    $vbs = @"
' free-claude-code hidden launcher (Task Scheduler)
CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$wrapperPath""", 0, False
"@
    Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII

    # 移除舊的 task（若存在）
    Unregister-ScheduledTask -TaskName $SERVICE_NAME -Confirm:$false -ErrorAction SilentlyContinue

    # wscript //B：完全不顯示視窗；由 VBS 再呼叫 Hidden PowerShell 啟動 proxy
    $action  = New-ScheduledTaskAction -Execute "wscript.exe" `
                 -Argument "//B `"$vbsPath`""
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
    $endMarker = "# ── end free-claude-code aliases ──"

    $aliases = @"

$marker
function fcc-status {
    `$task = Get-ScheduledTask -TaskName '$SERVICE_NAME'
    `$task | Select-Object TaskName, State
    Write-Host ""
    if (Get-NetTCPConnection -LocalPort $FCC_PORT -State Listen -ErrorAction SilentlyContinue) {
        Write-Host "[OK]    port $FCC_PORT 正在監聽" -ForegroundColor Green
    } else {
        Write-Host "[WARN]  port $FCC_PORT 無服務（State=Ready 表示排程閒置，請執行 fcc-start）" -ForegroundColor Yellow
    }
    try {
        `$null = Invoke-WebRequest -Uri "http://localhost:$FCC_PORT/health" -Headers @{ Authorization = "Bearer $ANTHROPIC_AUTH_TOKEN" } -UseBasicParsing -TimeoutSec 3
        Write-Host "[OK]    Proxy API 回應正常" -ForegroundColor Green
    } catch {
        Write-Host "[WARN]  Proxy API 無回應" -ForegroundColor Yellow
    }
}
function fcc-kill {
    Stop-ScheduledTask -TaskName '$SERVICE_NAME' -ErrorAction SilentlyContinue
    @('free-claude-code', 'fcc-server') | ForEach-Object {
        Get-Process -Name `$_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { `$_.CommandLine -and `$_.CommandLine -like '*free-claude-code*' } |
        ForEach-Object { Stop-Process -Id `$_.ProcessId -Force -ErrorAction SilentlyContinue }
}
function fcc-start   {
    fcc-kill
    Start-Sleep -Seconds 1
    Start-ScheduledTask -TaskName '$SERVICE_NAME'
    Write-Host "已觸發啟動，約 5 秒後執行 fcc-status 確認" -ForegroundColor Green
}
function fcc-stop    { fcc-kill; Write-Host "Proxy 已停止" -ForegroundColor Yellow }
function fcc-restart { fcc-stop; Start-Sleep -Seconds 2; fcc-start }
function fcc-log     {
    `$stdout = '$FCC_LOG_DIR\fcc.log'
    `$stderr = '$FCC_LOG_DIR\fcc-error.log'
    Write-Host 'fcc-log' -ForegroundColor Cyan
    Write-Host "  stdout: `$stdout"
    Write-Host "  stderr: `$stderr"
    Write-Host ''
    `$existing = @(`$stdout, `$stderr) | Where-Object { Test-Path `$_ }
    if (-not `$existing) {
        Write-Host '尚無 log 檔' -ForegroundColor Yellow
        return
    }
    foreach (`$p in `$existing) {
        Write-Host "--- `$p (recent 100) ---" -ForegroundColor DarkGray
        Get-Content -Path `$p -Tail 100
        Write-Host ''
    }
    Write-Host '--- live (Ctrl+C to exit) ---' -ForegroundColor DarkGray
    Get-Content -Path `$existing -Tail 0 -Wait
}
function fcc-claude  {
    `$env:ANTHROPIC_AUTH_TOKEN = "$ANTHROPIC_AUTH_TOKEN"
    `$env:ANTHROPIC_BASE_URL   = "http://localhost:$FCC_PORT"
    `$env:CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1"
    claude
}
$endMarker
"@

    if (Select-String -Path $PROFILE -Pattern $marker -Quiet) {
        $profileText = Get-Content -Path $PROFILE -Raw
        $pattern = [regex]::Escape($marker) + '[\s\S]*?' + [regex]::Escape($endMarker)
        $profileText = [regex]::Replace($profileText, $pattern, $aliases.Trim())
        Set-Content -Path $PROFILE -Value $profileText -Encoding UTF8
        Write-Success "Alias 已更新 PowerShell Profile"
    } else {
        Add-Content -Path $PROFILE -Value $aliases
        Write-Success "Alias 已寫入 PowerShell Profile"
    }
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
Install-Node
Install-ClaudeCode
Install-Fcc
Write-Config -ApiKey $ApiKey
Install-TaskScheduler -ApiKey $ApiKey
Write-Aliases

Add-ManifestItem @{ id = "config"; path = $FCC_ENV }
Add-ManifestItem @{ id = "service"; type = "task-scheduler"; name = $SERVICE_NAME }
Add-ManifestItem @{ id = "shell-aliases"; target = "powershell-profile" }
Write-Manifest

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
