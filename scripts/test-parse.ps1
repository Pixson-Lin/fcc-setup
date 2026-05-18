$files = @(
    "$PSScriptRoot\..\install.ps1",
    "$PSScriptRoot\..\uninstall.ps1"
)
foreach ($f in $files) {
    $f = (Resolve-Path $f).Path
    $bom = [byte[]](Get-Content $f -Encoding Byte -TotalCount 3)
    $hasBom = ($bom[0] -eq 239 -and $bom[1] -eq 187 -and $bom[2] -eq 191)
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs)
    if ($errs) {
        Write-Host "FAIL $f BOM=$hasBom"
        $errs | ForEach-Object { Write-Host $_.ToString() }
        exit 1
    }
    Write-Host "OK $f BOM=$hasBom"
}
