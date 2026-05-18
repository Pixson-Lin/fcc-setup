# =============================================================================
# free-claude-code 反安裝腳本 (Windows PowerShell)
# 用法: .\uninstall.ps1  或雙擊 uninstall.bat
# =============================================================================

$ErrorActionPreference = "Stop"

$FCC_CONFIG_DIR = "$env:APPDATA\free-claude-code"
$FCC_ENV        = "$FCC_CONFIG_DIR\.env"
$FCC_LOG_DIR    = "$env:LOCALAPPDATA\free-claude-code\logs"
$FCC_MANIFEST   = "$FCC_CONFIG_DIR\install-manifest.json"
$SERVICE_NAME   = "FreeClaudeCodeProxy"
$FCC_PORT       = 8082

function Write-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

function Invoke-Native {
    param([scriptblock]$Command, [switch]$Quiet)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Quiet) { & $Command 2>&1 | Out-Null } else { & $Command 2>&1 }
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Stop-Fcc {
    Write-Info "停止 free-claude-code..."
    Stop-ScheduledTask -TaskName $SERVICE_NAME -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $SERVICE_NAME -Confirm:$false -ErrorAction SilentlyContinue

    @('free-claude-code', 'fcc-server') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*free-claude-code*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
}

function Show-ManualPaths {
    Write-Host ""
    Write-Host "可手動清理的路徑：" -ForegroundColor Yellow
    Write-Host "  $FCC_CONFIG_DIR"
    Write-Host "  $FCC_LOG_DIR"
    Write-Host "  Task Scheduler: $SERVICE_NAME"
    Write-Host "  PowerShell Profile 內 # free-claude-code aliases 區塊"
    Write-Host ""
}

function Get-ManifestItem {
    param($Manifest, [string]$Id)
    if (-not $Manifest -or -not $Manifest.items) { return $null }
    return $Manifest.items | Where-Object { $_.id -eq $Id } | Select-Object -First 1
}

function Remove-ProfileAliases {
    if (-not (Test-Path $PROFILE)) { return }
    $marker = "# free-claude-code aliases"
    $endMarker = "# ── end free-claude-code aliases ──"
    if (-not (Select-String -Path $PROFILE -Pattern $marker -Quiet)) { return }
    $profileText = Get-Content -Path $PROFILE -Raw
    $pattern = [regex]::Escape($marker) + '[\s\S]*?' + [regex]::Escape($endMarker)
    $profileText = [regex]::Replace($profileText, $pattern, '').TrimEnd()
    Set-Content -Path $PROFILE -Value ($profileText + "`n") -Encoding UTF8
    Write-Success "已移除 PowerShell Profile alias 區塊"
}

function Remove-Core {
    Stop-Fcc
    Remove-ProfileAliases

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Info "移除 uv tool: free-claude-code..."
        Invoke-Native { uv tool uninstall free-claude-code } -Quiet
    }

    @(
        "$FCC_CONFIG_DIR\start-fcc.ps1",
        "$FCC_CONFIG_DIR\start-fcc-hidden.vbs",
        $FCC_ENV,
        $FCC_MANIFEST
    ) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Force -ErrorAction SilentlyContinue
            Write-Info "已刪除 $_"
        }
    }

    if (Test-Path $FCC_CONFIG_DIR) {
        $remaining = Get-ChildItem $FCC_CONFIG_DIR -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item $FCC_CONFIG_DIR -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-Advanced {
    param($Manifest, [string[]]$Ids)

    foreach ($id in $Ids) {
        $item = Get-ManifestItem $Manifest $id
        if (-not $item -or -not $item.installed_by_script) { continue }

        switch ($id) {
            'python' {
                if (Get-Command uv -ErrorAction SilentlyContinue) {
                    Write-Info "移除 Python 3.14 (uv)..."
                    Invoke-Native { uv python uninstall 3.14 } -Quiet
                }
            }
            'claude-code' {
                if (Get-Command npm -ErrorAction SilentlyContinue) {
                    Write-Info "移除 Claude Code (npm global)..."
                    Invoke-Native { npm uninstall -g @anthropic-ai/claude-code } -Quiet
                }
            }
            'uv' {
                $uvItem = Get-ManifestItem $Manifest 'uv'
                if ($uvItem.path -and (Test-Path $uvItem.path)) {
                    Write-Info "移除 uv ($($uvItem.path))..."
                    Remove-Item $uvItem.path -Force -ErrorAction SilentlyContinue
                }
            }
            'nodejs' {
                Write-Warn "Node.js 請至 Windows 設定 - 應用程式 手動解除安裝（winget: winget uninstall OpenJS.NodeJS.LTS）"
            }
        }
    }
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "free-claude-code 反安裝" -ForegroundColor Cyan
Write-Host ""

$manifest = $null
if (Test-Path $FCC_MANIFEST) {
    try {
        $manifest = Get-Content $FCC_MANIFEST -Raw | ConvertFrom-Json
        Write-Info "讀取安裝紀錄: $FCC_MANIFEST (v$($manifest.fcc_setup_version), $($manifest.installed_at))"
    } catch {
        Write-Warn "無法解析 install-manifest.json，將僅依預設路徑清理"
    }
} else {
    Write-Warn "未偵測到安裝紀錄 ($FCC_MANIFEST)"
    Show-ManualPaths
    $cont = Read-Host "仍要嘗試清理 fcc 核心項目？(y/N)"
    if ($cont -notmatch '^[yY]') { exit 0 }
}

Write-Host ""
Write-Host "── 將移除（fcc 核心，預設）──" -ForegroundColor Yellow
Write-Host "  Task Scheduler: $SERVICE_NAME"
Write-Host "  Proxy tool (uv tool uninstall free-claude-code)"
Write-Host "  設定檔: $FCC_ENV " -NoNewline
Write-Host "（含 API key）" -ForegroundColor Yellow
Write-Host "  啟動腳本: start-fcc.ps1, start-fcc-hidden.vbs"
Write-Host "  install-manifest.json"
Write-Host "  PowerShell Profile alias 區塊"
if ($manifest) {
    $fcc = Get-ManifestItem $manifest 'free-claude-code'
    if ($fcc -and $fcc.commit) {
        $pv = if ($fcc.package_version) { ", v$($fcc.package_version)" } else { "" }
        Write-Host "  已安裝 proxy: commit $($fcc.commit.Substring(0, [Math]::Min(7, $fcc.commit.Length)))$pv" -ForegroundColor DarkGray
    }
}
Write-Host ""

$confirm = Read-Host "確認移除 fcc 核心項目？(y/N)"
if ($confirm -notmatch '^[yY]') {
    Write-Info "已取消"
    exit 0
}

$advancedIds = @()
if ($manifest) {
    $candidates = @('uv', 'python', 'nodejs', 'claude-code')
    $advancedIds = $candidates | Where-Object {
        $it = Get-ManifestItem $manifest $_
        $it -and $it.installed_by_script -eq $true
    }
}

$removeAdvanced = @()
if ($advancedIds.Count -gt 0) {
    Write-Host ""
    Write-Host "── 進階選項（僅列出安裝腳本曾安裝的項目）──" -ForegroundColor Yellow
    foreach ($id in $advancedIds) {
        Write-Host "  [ ] $id (installed_by_script: true)"
    }
    Write-Host ""
    $adv = Read-Host "一併移除進階項目？輸入逗號分隔 id（如 python,claude-code）或 Enter 跳過"
    if ($adv) {
        $removeAdvanced = $adv -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
}

$deleteLogs = Read-Host "是否刪除 log 目錄 $FCC_LOG_DIR ？(y/N)"

Stop-Fcc
Remove-Core
if ($removeAdvanced.Count -gt 0) {
    Remove-Advanced -Manifest $manifest -Ids $removeAdvanced
}
if ($deleteLogs -match '^[yY]' -and (Test-Path $FCC_LOG_DIR)) {
    Remove-Item $FCC_LOG_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "已刪除 log 目錄"
}

Write-Host ""
Write-Success "反安裝完成"
Write-Host "  若曾安裝 Node.js (winget)，可能需手動解除安裝" -ForegroundColor DarkGray
Write-Host ""
