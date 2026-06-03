param(
  [switch]$SkipRules
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$ArtifactsDir = Join-Path $Root "test_artifacts/full_testing"
$SummaryFile = Join-Path $ArtifactsDir "summary.md"
New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

$startedAt = Get-Date
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
  param([string]$Name, [string]$Status, [string]$Details)
  $results.Add([pscustomobject]@{
    Name = $Name
    Status = $Status
    Details = $Details
  })
}

function Run-Script {
  param([string]$Name, [string]$ScriptName)

  Write-Host "`n========== $Name =========="
  try {
    & (Join-Path $PSScriptRoot $ScriptName) -ArtifactsDir $ArtifactsDir
    if ($LASTEXITCODE -ne 0) {
      throw "$Name exited with $LASTEXITCODE"
    }
    Add-Result $Name "PASS" ""
  } catch {
    Add-Result $Name "FAIL" $_.Exception.Message
    Write-Summary
    throw
  }
}

function Assert-NoUnignoredServiceAccounts {
  $allowed = @(
    "perfume-auth-worker/service-account.json",
    "perfume-orders-worker/service-account.json"
  )
  $files = Get-ChildItem -Path $Root -Recurse -Filter "service-account*.json" -File |
    ForEach-Object {
      $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    }

  $violations = $files | Where-Object {
    $relative = $_
    -not ($relative.StartsWith("secret/") -or $allowed.Contains($relative))
  }

  if ($violations) {
    throw "Service account files outside allowed ignored local paths: $($violations -join ', ')"
  }
}

function Assert-ResetWebNotOfficialFlow {
  $output = & rg -n "resetPassWeb" "lib" "perfume_app_admin_dashboard/lib" 2>&1
  $code = $LASTEXITCODE
  if ($code -eq 0) {
    throw "Reset web path appears in official UI flow: $($output -join '; ')"
  } elseif ($code -gt 1) {
    throw "reset web static guard failed with rg exit code $code"
  }

  $sendResetCalls = & rg -n "sendPasswordResetEmail" "lib" 2>&1
  $sendResetCode = $LASTEXITCODE
  if ($sendResetCode -eq 0) {
    $unexpectedCalls = $sendResetCalls | Where-Object {
      $_ -notmatch "lib\\features\\auth\\data\\auth_repository.dart"
    }
    if ($unexpectedCalls) {
      throw "Legacy Firebase reset email is called outside the repository: $($unexpectedCalls -join '; ')"
    }
  } elseif ($sendResetCode -gt 1) {
    throw "legacy reset call static guard failed with rg exit code $sendResetCode"
  }

  $global:LASTEXITCODE = 0
}

function Run-StaticGuards {
  $logFile = Join-Path $ArtifactsDir "static_guards.log"
  Set-Content -Path $logFile -Value "# Static Guards`n"

  Write-Host "`n========== Static guards =========="
  try {
    $mockOutput = & rg -n "mock\\." "perfume_app_admin_dashboard/lib" "perfume_app_admin_dashboard/assets/i18n" 2>&1
    $mockCode = $LASTEXITCODE
    if ($mockCode -eq 0) {
      $mockOutput | Tee-Object -FilePath $logFile -Append
      throw "Forbidden admin mock references found."
    }
    if ($mockCode -gt 1) {
      throw "Admin mock static guard failed with rg exit code $mockCode."
    }
    Assert-NoUnignoredServiceAccounts
    Assert-ResetWebNotOfficialFlow
    Add-Content -Path $logFile -Value "Static guards passed."
    Add-Result "Static guards" "PASS" ""
  } catch {
    Add-Content -Path $logFile -Value $_.Exception.Message
    Add-Result "Static guards" "FAIL" $_.Exception.Message
    Write-Summary
    throw
  }
}

function Write-Summary {
  $endedAt = Get-Date
  $gitHead = ""
  try {
    $gitHead = (& git rev-parse --short HEAD 2>$null)
  } catch {
    $gitHead = "unavailable"
  }
  $gitState = ""
  try {
    $gitState = (& git status --short 2>$null) -join "`n"
  } catch {
    $gitState = "unavailable"
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Full Testing Summary")
  $lines.Add("")
  $lines.Add("- Started: $($startedAt.ToString("yyyy-MM-dd HH:mm:ss zzz"))")
  $lines.Add("- Finished: $($endedAt.ToString("yyyy-MM-dd HH:mm:ss zzz"))")
  $lines.Add("- Git HEAD: $gitHead")
  $lines.Add("")
  $lines.Add("## Results")
  foreach ($result in $results) {
    $detail = if ($result.Details) { " - $($result.Details)" } else { "" }
    $lines.Add("- $($result.Status): $($result.Name)$detail")
  }
  $lines.Add("")
  $lines.Add("## Commands Covered")
  $lines.Add("- flutter analyze")
  $lines.Add("- flutter test")
  $lines.Add("- admin flutter analyze")
  $lines.Add("- admin flutter test")
  $lines.Add("- AI/Auth/Orders worker npm test")
  if (-not $SkipRules) {
    $lines.Add("- firebase emulators:exec --only firestore `"npm --prefix functions run test:rules`"")
  }
  $lines.Add("- static mock/security guards")
  $lines.Add("")
  $lines.Add("## Known Manual Checks Still Required")
  $lines.Add("- Real device layout sanity")
  $lines.Add("- Real network AI latency")
  $lines.Add("- OTP email delivery through Resend")
  $lines.Add("- Admin dashboard visual review with empty and populated Firestore")
  $lines.Add("- Backup recording playback")
  $lines.Add("")
  $lines.Add("## Workspace State")
  if ($gitState) {
    $lines.Add('```')
    $lines.Add($gitState)
    $lines.Add('```')
  } else {
    $lines.Add("Clean or git status unavailable.")
  }

  Set-Content -Path $SummaryFile -Value $lines
}

Run-Script "Main app" "test_main_app.ps1"
Run-Script "Admin dashboard" "test_admin_dashboard.ps1"
Run-Script "Workers" "test_workers.ps1"
if (-not $SkipRules) {
  Run-Script "Firestore rules" "test_rules.ps1"
}
Run-StaticGuards
Write-Summary

Write-Host "`nFull testing run passed. Summary: $SummaryFile"
