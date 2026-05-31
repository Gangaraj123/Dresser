# tunnel_and_run.ps1
# 1. Starts zrok tunnel for the backend port
# 2. Waits until zrok prints the public URL
# 3. Updates dresser_app/.env with the new API_BASE_URL
# 4. Launches Flutter

param(
    [string]$ZrokPath    = "C:\Users\rajini bopparam\Downloads\zrok_1.1.11_windows_amd64\zrok.exe",
    [string]$BackendPort = "3005",
    [string]$EnvFile     = "$PSScriptRoot\..\dresser_app\.env",
    [string]$FlutterDir  = "$PSScriptRoot\..\dresser_app"
)

$ErrorActionPreference = "Stop"

$EnvFile    = (Resolve-Path $EnvFile).Path
$FlutterDir = (Resolve-Path $FlutterDir).Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dresser Dev - Tunnel + Flutter"        -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backend port : $BackendPort"
Write-Host "  .env file    : $EnvFile"
Write-Host ""

# --- Start zrok ---
Write-Host ">> Starting zrok tunnel..." -ForegroundColor Yellow

$tempOut = [System.IO.Path]::GetTempFileName()
$zrokProc = Start-Process `
    -FilePath $ZrokPath `
    -ArgumentList "share", "public", "localhost:$BackendPort" `
    -RedirectStandardOutput $tempOut `
    -PassThru `
    -NoNewWindow

Write-Host "   zrok PID: $($zrokProc.Id)"

# --- Wait for URL ---
Write-Host ">> Waiting for tunnel URL..." -ForegroundColor Yellow

$tunnelUrl = $null
$attempts  = 0
$maxWait   = 60

while (-not $tunnelUrl -and $attempts -lt ($maxWait * 2)) {
    Start-Sleep -Milliseconds 500
    $attempts++
    if (Test-Path $tempOut) {
        $content = Get-Content $tempOut -Raw -ErrorAction SilentlyContinue
        if ($content -match 'https://[a-zA-Z0-9\-]+\.share\.zrok\.io') {
            $tunnelUrl = $Matches[0].TrimEnd('/')
        }
    }
}

if (-not $tunnelUrl) {
    Write-Host ""
    Write-Host "ERROR: Could not detect zrok URL after ${maxWait}s." -ForegroundColor Red
    Write-Host "       Is the backend running on port $BackendPort ?" -ForegroundColor Red
    $zrokProc | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""
Write-Host "   Tunnel URL: $tunnelUrl" -ForegroundColor Green
Write-Host ""

# --- Update dresser_app/.env ---
Write-Host ">> Updating $EnvFile ..." -ForegroundColor Yellow

$envContent = Get-Content $EnvFile -Raw

if ($envContent -match 'API_BASE_URL=.*') {
    $envContent = $envContent -replace 'API_BASE_URL=.*', "API_BASE_URL=$tunnelUrl"
} else {
    $envContent = $envContent.TrimEnd() + "`nAPI_BASE_URL=$tunnelUrl`n"
}

Set-Content -Path $EnvFile -Value $envContent -NoNewline
Write-Host "   API_BASE_URL set to $tunnelUrl" -ForegroundColor Green
Write-Host ""

# --- Cleanup zrok when terminal closes ---
$zrokPid = $zrokProc.Id
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Stop-Process -Id $zrokPid -Force -ErrorAction SilentlyContinue
}

# --- Launch Flutter ---
Write-Host ">> Starting Flutter..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $FlutterDir
flutter run

# --- Cleanup ---
Write-Host ""
Write-Host ">> Flutter exited. Stopping zrok (PID $zrokPid)..." -ForegroundColor Yellow
Stop-Process -Id $zrokPid -Force -ErrorAction SilentlyContinue
Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
Write-Host "   Done." -ForegroundColor Green
