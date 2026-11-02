# Publish every versioned build in Releases\ as a GitHub Release.
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

    $notes = @"
Megaudio $ver - build artifacts.

- windows zip: extract and run megaudio.exe (keep the data folder next to it)
- android apk: install on Android 7+ (allow install from unknown sources)
- web zip: deploy to any static web server
"@

    & $gh release create $ver --repo $repo --title "Megaudio $ver" --notes $notes $assets 2>$null
    if ($LASTEXITCODE -eq 0) {
        Remove-Item $zipWin, $zipWeb -Force
        Write-Host "published $ver"
    } else {
        Write-Host "FAILED $ver"
    }
}

Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'RELEASES DONE'
