# Publish every versioned build in Releases\ as a GitHub Release.
# Release notes come from CHANGELOG.md (section "## v<version>").
# ASCII only (PowerShell 5.1).
$root = 'E:\Flutter\projects\audiophile_pro'
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$repo = 'noet123456/Megaudio'
$staging = Join-Path $root 'Releases\_assets'
New-Item -ItemType Directory -Force $staging | Out-Null

# Native commands write progress to stderr; in PS 5.1 that looks like an
# error when $ErrorActionPreference is Stop. Keep it non-terminating and
# check $LASTEXITCODE explicitly instead.
$ErrorActionPreference = 'Continue'

function Get-ReleaseNotes([string]$version) {
    $cl = Join-Path $root 'CHANGELOG.md'
    if (-not (Test-Path $cl)) { return $null }
    $lines = Get-Content $cl -Encoding UTF8
    $sb = New-Object System.Text.StringBuilder
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match '^##\s+(.+)$') {
            if ($inside) { break }
            $inside = ($Matches[1].Trim() -eq $version)
            continue
        }
        if ($inside) { [void]$sb.AppendLine($line) }
    }
    $text = $sb.ToString().Trim()
    if ($text.Length -gt 0) { return $text }
    return $null
}

$vers = Get-ChildItem (Join-Path $root 'Releases') -Directory |
    Where-Object { $_.Name -like 'v*' } |
    Sort-Object { [version]($_.Name.TrimStart('v').Split('+')[0]) }

foreach ($v in $vers) {
    $ver = $v.Name                     # e.g. v1.8.1+12
    $verNoV = $ver.TrimStart('v')

    $null = & $gh release view $ver --repo $repo --json tagName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "skip $ver (already published)"
        continue
    }

    Write-Host "=== publishing $ver ==="
    $zipWin = Join-Path $staging "megaudio_${verNoV}_windows.zip"
    $zipWeb = Join-Path $staging "megaudio_${verNoV}_web.zip"

    if (-not (Test-Path $zipWin)) {
        Compress-Archive -Path (Join-Path $v.FullName 'windows\*') -DestinationPath $zipWin -CompressionLevel Optimal
    }
    if (-not (Test-Path $zipWeb)) {
        Compress-Archive -Path (Join-Path $v.FullName 'web\*') -DestinationPath $zipWeb -CompressionLevel Optimal
    }

    $assets = @($zipWin, $zipWeb)
    $apk = Get-ChildItem (Join-Path $v.FullName 'android\*.apk') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($apk) { $assets += $apk.FullName }

    $notes = Get-ReleaseNotes $ver
    if (-not $notes) {
        $notes = "Megaudio $ver - build artifacts.`n`n- windows zip: extract and run megaudio.exe`n- android apk: install on Android 7+`n- web zip: deploy to any static web server"
    }

    # UTF-8 without BOM so Vietnamese notes survive PowerShell 5.1.
    $notesFile = Join-Path $staging "$ver.notes.md"
    [System.IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding($false)))

    & $gh release create $ver --repo $repo --title "Megaudio $ver" --notes-file $notesFile $assets 2>$null
    if ($LASTEXITCODE -eq 0) {
        Remove-Item $zipWin, $zipWeb, $notesFile -Force
        Write-Host "published $ver"
    } else {
        Write-Host "FAILED $ver"
    }
}

Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'RELEASES DONE'
