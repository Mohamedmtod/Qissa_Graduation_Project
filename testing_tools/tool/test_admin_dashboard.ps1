param(
  [string]$ArtifactsDir
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AdminDir = Join-Path $Root "perfume_app_admin_dashboard"
if (-not $ArtifactsDir) {
  $ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
}
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null
$LogFile = Join-Path $ArtifactsDir "admin_dashboard_test.log"
Set-Content -Path $LogFile -Value "# Admin Dashboard Test Run`n"

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

function Assert-NoRgMatch {
  param(
    [string]$Name,
    [string]$Pattern,
    [string[]]$Paths
  )

  Add-Content -Path $LogFile -Value "`n## $Name`nCommand: rg -n $Pattern $($Paths -join ' ')`n"
  Write-Host "==> $Name"
  Push-Location $Root
  try {
    $output = & rg -n $Pattern @Paths 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) {
      $output | Tee-Object -FilePath $LogFile -Append
      throw "$Name failed: forbidden references found."
    }
    if ($code -gt 1) {
      $output | Tee-Object -FilePath $LogFile -Append
      throw "$Name failed: rg exited with $code."
    }
    Add-Content -Path $LogFile -Value "No matches."
    $global:LASTEXITCODE = 0
  } finally {
    Pop-Location
  }
}

Run-Step -Name "Admin flutter analyze" -WorkingDirectory $AdminDir -Command @("flutter", "analyze")
Run-Step -Name "Admin flutter test" -WorkingDirectory $AdminDir -Command @("flutter", "test")
Assert-NoRgMatch "No admin mock localization or production references" "mock\\." @(
  "perfume_app_admin_dashboard/lib",
  "perfume_app_admin_dashboard/assets/i18n"
)

Write-Host "Admin dashboard tests passed."
