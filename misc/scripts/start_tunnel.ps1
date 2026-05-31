# start_tunnel.ps1
# Starts zrok tunnel, waits for URL, updates dresser_app/.env
# Stays running so the tunnel stays alive.

param(
    [string]$ZrokPath    = "C:\Users\rajini bopparam\Downloads\zrok_1.1.11_windows_amd64\zrok.exe",
    [string]$BackendPort = "3005",
    [string]$EnvFile     = "$PSScriptRoot\..\dresser_app\.env"
)

$ErrorActionPreference = "Stop"
$EnvFile = (Resolve-Path $EnvFile).Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dresser Dev - zrok Tunnel"             -ForegroundColor Cyan
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
Write-Host "   Tunnel is live. Keep this terminal open." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Stay alive until Ctrl+C ---
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Stop-Process -Id $zrokProc.Id -Force -ErrorAction SilentlyContinue
    Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
}

try {
    $zrokProc.WaitForExit()
} finally {
    Stop-Process -Id $zrokProc.Id -Force -ErrorAction SilentlyContinue
    Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
}
