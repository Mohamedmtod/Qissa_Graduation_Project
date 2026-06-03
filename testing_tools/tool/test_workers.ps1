param(
  [string]$ArtifactsDir
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $ArtifactsDir) {
  $ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
}
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
$LogFile = Join-Path $ArtifactsDir "workers_test.log"
Set-Content -Path $LogFile -Value "# Workers Test Run`n"

function Run-Step {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [string[]]$Command
  )

  Add-Content -Path $LogFile -Value "`n## $Name`nCommand: $($Command -join ' ')`n"
  Write-Host "==> $Name"
  Push-Location $WorkingDirectory
  try {
    $exe = $Command[0]
    $cmdArgs = @()
    if ($Command.Length -gt 1) {
      $cmdArgs = @($Command | Select-Object -Skip 1)
    }
    & $exe @cmdArgs 2>&1 |
      Tee-Object -FilePath $LogFile -Append
    if ($LASTEXITCODE -ne 0) {
      throw "$Name failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

Run-Step -Name "AI worker npm test" -WorkingDirectory (Join-Path $Root "perfume-ai-chat-worker") -Command @("npm.cmd", "test")
Run-Step -Name "Auth worker npm test" -WorkingDirectory (Join-Path $Root "perfume-auth-worker") -Command @("npm.cmd", "test")
Run-Step -Name "Orders worker npm test" -WorkingDirectory (Join-Path $Root "perfume-orders-worker") -Command @("npm.cmd", "test")

Write-Host "Worker tests passed."
