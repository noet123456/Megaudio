# ============================================================================
# Megaudio - versioned release builder (ASCII only for PS 5.1)
# Usage:
#   .\tools\build_release.ps1                       # builds windows + apk + web
#   .\tools\build_release.ps1 -Targets windows,web  # builds selected targets
#
# Each run creates a NEW folder under Releases\<version>\ (version read from
# pubspec.yaml). Previous version folders are never overwritten.
# ============================================================================
param(
    [ValidateSet('windows', 'apk', 'web')]
    [string[]]$Targets = @('windows', 'apk', 'web')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterBat  = 'E:\Flutter\flutter\bin\flutter.bat'
$env:JAVA_HOME = 'E:\Flutter\jdk\jdk-17.0.20.1+1'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

# --- Read version from pubspec.yaml ---
$pubspec = Get-Content "$projectRoot\pubspec.yaml" -Raw
if ($pubspec -match '(?m)^version:\s*([0-9A-Za-z+\.\-]+)') {
    $version = $Matches[1]
} else {
    throw 'Cannot read version from pubspec.yaml'
}

$dstRoot = Join-Path $projectRoot "Releases\v$version"
New-Item -ItemType Directory -Force $dstRoot | Out-Null

Write-Host "=== Building Megaudio v$version ===" -ForegroundColor Cyan

foreach ($target in $Targets) {
    Write-Host "`n--- Building $target ---" -ForegroundColor Yellow
    if ($target -eq 'windows') {
        Stop-Process -Name megaudio -Force -ErrorAction SilentlyContinue
        & $flutterBat build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
        $dst = Join-Path $dstRoot 'windows'
        robocopy "$projectRoot\build\windows\x64\runner\Release" $dst /MIR /NFL /NDL /NJH | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy windows output failed" }
        Write-Host "Windows release copied to $dst" -ForegroundColor Green
    }
    elseif ($target -eq 'apk') {
        & $flutterBat build apk --release
        if ($LASTEXITCODE -ne 0) { throw "APK build failed" }
        $dst = Join-Path $dstRoot 'android'
        New-Item -ItemType Directory -Force $dst | Out-Null
        Copy-Item "$projectRoot\build\app\outputs\flutter-apk\app-release.apk" `
            (Join-Path $dst "megaudio_v$version.apk") -Force
        Write-Host "APK copied to $dst" -ForegroundColor Green
    }
    elseif ($target -eq 'web') {
        & $flutterBat build web --release
        if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
        $dst = Join-Path $dstRoot 'web'
        robocopy "$projectRoot\build\web" $dst /MIR /NFL /NDL /NJH | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy web output failed" }
        Write-Host "Web release copied to $dst" -ForegroundColor Green
    }
}

# --- Build info ---
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$info = @"
Megaudio - Release v$version
Built: $stamp
Targets: $($Targets -join ', ')
- windows\: megaudio.exe (run directly; keep dll files and data\ folder together)
- android\  : install the .apk on Android (enable install-unknown-sources if asked)
- web\      : deploy to any static web server (nginx, IIS, GitHub Pages...)
"@
Set-Content (Join-Path $dstRoot 'BUILD_INFO.txt') $info

Write-Host "`n=== DONE - Releases\v$version ===" -ForegroundColor Cyan
