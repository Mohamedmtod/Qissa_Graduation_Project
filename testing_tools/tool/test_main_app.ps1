param(
  [string]$ArtifactsDir
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $ArtifactsDir) {
  $ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
}
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
$LogFile = Join-Path $ArtifactsDir "main_app_test.log"
Set-Content -Path $LogFile -Value "# Main App Test Run`n"

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

Run-Step -Name "Root flutter analyze" -WorkingDirectory $Root -Command @("flutter", "analyze")
Run-Step -Name "Root flutter test" -WorkingDirectory $Root -Command @("flutter", "test")

Write-Host "Main app tests passed."
