param(
  [switch]$NoStart
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
$PidFile = Join-Path $ArtifactsDir "local_stack_pids.txt"
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

$ports = @(8080, 9099, 8787, 8788, 8789)
foreach ($port in $ports) {
  $busy = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
  if ($busy) {
    throw "Port $port is already busy. Stop the existing process before starting the local test stack."
  }
}

if ($NoStart) {
  Write-Host "Ports are free. Use without -NoStart to launch the local test stack."
  exit 0
}

Set-Content -Path $PidFile -Value "# Local test stack PIDs`n"

function Start-TestProcess {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [string]$Command
  )

  Write-Host "Starting $Name"
  $process = Start-Process powershell `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $Command) `
    -WorkingDirectory $WorkingDirectory `
    -WindowStyle Hidden `
    -PassThru
  Add-Content -Path $PidFile -Value "$Name=$($process.Id)"
}

Start-TestProcess "firebase-emulators" $Root "firebase emulators:start --only firestore,auth"
Start-TestProcess "ai-worker" (Join-Path $Root "perfume-ai-chat-worker") "npx wrangler dev --local --port 8787"
Start-TestProcess "auth-worker" (Join-Path $Root "perfume-auth-worker") "npx wrangler dev --local --port 8788"
Start-TestProcess "orders-worker" (Join-Path $Root "perfume-orders-worker") "npx wrangler dev --local --port 8789"

Write-Host "Local test stack launch requested. PID file: $PidFile"
Write-Host "Dart defines for emulator profile:"
Write-Host "--dart-define=USE_FIREBASE_EMULATORS=true"
Write-Host "--dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080"
Write-Host "--dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099"
Write-Host "--dart-define=ORDERS_WORKER_URL=http://127.0.0.1:8789"
Write-Host "--dart-define=AUTH_WORKER_URL=http://127.0.0.1:8788"
Write-Host "--dart-define=AI_CHAT_WORKER_URL=http://127.0.0.1:8787"
Write-Host "--dart-define=AI_CHAT_USE_REAL_BACKEND=true"
Write-Host "--dart-define=AI_CHAT_BYPASS_AUTH=false"
