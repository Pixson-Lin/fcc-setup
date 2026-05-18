param([Parameter(Mandatory)][string[]]$Paths)
$utf8Bom = New-Object System.Text.UTF8Encoding $true
foreach ($p in $Paths) {
    $full = Resolve-Path -LiteralPath $p
    $text = [System.IO.File]::ReadAllText($full)
    [System.IO.File]::WriteAllText($full, $text, $utf8Bom)
    Write-Host "UTF-8 BOM: $full"
}
