param(
  [string]$ArtifactsDir
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $ArtifactsDir) {
  $ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
}
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
$LogFile = Join-Path $ArtifactsDir "firestore_rules_test.log"
Set-Content -Path $LogFile -Value "# Firestore Rules Test Run`n"

function Stop-FirestoreRulesEmulator {
  $processes = Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -eq "java.exe" -and
      $_.CommandLine -and
      $_.CommandLine.Contains("cloud-firestore-emulator") -and
      $_.CommandLine.Contains("firestore.rules")
    }

  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
      Add-Content -Path $LogFile -Value "Stopped leftover Firestore emulator process $($process.ProcessId)."
    } catch {
      Add-Content -Path $LogFile -Value "Could not stop Firestore emulator process $($process.ProcessId): $($_.Exception.Message)"
    }
  }
}

Write-Host "==> Firestore rules emulator tests"
Push-Location $Root
try {
  firebase emulators:exec --only firestore "npm --prefix functions run test:rules" 2>&1 |
    Tee-Object -FilePath $LogFile -Append
  if ($LASTEXITCODE -ne 0) {
    throw "Firestore rules tests failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
  Stop-FirestoreRulesEmulator
}

Write-Host "Firestore rules tests passed."
