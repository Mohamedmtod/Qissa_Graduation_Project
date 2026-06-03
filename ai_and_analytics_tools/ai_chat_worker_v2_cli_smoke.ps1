param(
  [string]$WorkerUrl = "https://perfume-ai-chat-worker.qessa-prefume.workers.dev",
  [ValidateSet("GateMinus1", "Gate12")]
  [string]$Mode = "GateMinus1",
  [string]$OutDir = "test_artifacts/live_gate_logs",
  [ValidateSet("ar", "en")]
  [string]$ResponseLanguage = "ar"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$jsonlPath = Join-Path $OutDir "worker_v2_cli_${Mode}_$stamp.jsonl"
$summaryPath = Join-Path $OutDir "worker_v2_cli_${Mode}_$stamp.md"

function New-Candidates {
  return @(
    @{
      id = "catalog_refresh_07"; name = "Vanilla Smoke Halo"; brand = "Noura Atelier";
      price = 1180; gender = "women"; season = "winter";
      notes = @("vanilla", "smoke", "woody", "musk"); tags = @("gift", "warm");
      stock = 4; isActive = $true;
      reasonFacts = @{ matchedNotes = @("vanilla", "musk"); cautions = @() }
    },
    @{
      id = "catalog_refresh_22"; name = "Cedar Spice Focus"; brand = "Amber District";
      price = 2155; gender = "men"; season = "winter";
      notes = @("cedar", "spice", "citrus"); tags = @("formal", "strong");
      stock = 3; isActive = $true;
      reasonFacts = @{ matchedNotes = @("cedar", "spice"); cautions = @() }
    },
    @{
      id = "bleu_de_chanel"; name = "Bleu de Chanel"; brand = "Chanel";
      price = 4950; gender = "men"; season = "all_seasons";
      notes = @("citrus", "pepper", "woody", "fresh"); tags = @("fresh", "office");
      stock = 2; isActive = $true;
      reasonFacts = @{ matchedNotes = @("citrus", "fresh"); cautions = @() }
    },
    @{
      id = "fragrantica_50384"; name = "Cloud"; brand = "Ariana Grande";
      price = 2350; gender = "women"; season = "all_seasons";
      notes = @("musk", "sandalwood", "sweet"); tags = @("soft", "gift");
      stock = 5; isActive = $true;
      reasonFacts = @{ matchedNotes = @("musk", "sandalwood"); cautions = @() }
    }
  )
}

function New-Scenario(
  [string]$Id,
  [string]$Message,
  [hashtable]$Preferences,
  [object[]]$RecentMessages = @(),
  [string]$LastAssistantQuestion = $null,
  [string]$LastAskSlot = $null
) {
  return @{
    id = $Id
    currentMessage = $Message
    preferences = $Preferences
    recentMessages = $RecentMessages
    lastAssistantQuestion = $LastAssistantQuestion
    lastAskSlot = $LastAskSlot
  }
}

function Get-Scenarios {
  if ($Mode -eq "GateMinus1") {
    return @(
      (New-Scenario "G-1" "Recommend a light perfume for women" @{ gender = "women"; intensity = "light" })
    )
  }

  return @(
    (New-Scenario "S-micro-01" "for all seasons" @{ gender = "women"; maxBudget = 4500 } @(
      @{ role = "user"; text = "women" },
      @{ role = "assistant"; text = "Summer, winter, or all seasons?" },
      @{ role = "user"; text = "for all seasons" }
    ) "Summer, winter, or all seasons?" "season"),
    (New-Scenario "P50V2-001" "Dior 250" @{ maxBudget = 250 }),
    (New-Scenario "P50V2-003" "Do you have the original Channel Blue?" @{}),
    (New-Scenario "P50V2-005" "Remove vanilla and make it sandalwood with musk" @{ excludedNotes = @("vanilla"); notes = @("musk", "sandalwood") } @(
      @{ role = "user"; text = "Recommend a light musk and vanilla perfume" },
      @{ role = "assistant"; text = "I recommended options with vanilla and musk" },
      @{ role = "user"; text = "Remove vanilla and make it sandalwood with musk" }
    )),
    (New-Scenario "P50V2-009" "Explain perfume layering without recommending products" @{}),
    (New-Scenario "P50V2-013" "My budget is 600, and even if there is something better at 900 do not show it" @{ maxBudget = 600; budgetPolicy = "strict" }),
    (New-Scenario "P50V2-030" "Okay recommend something with vanilla anyway" @{ medicalExcludedNotes = @("vanilla"); excludedNotes = @("vanilla") } @(
      @{ role = "user"; text = "Vanilla gives me an allergy" },
      @{ role = "assistant"; text = "I will avoid vanilla for safety." },
      @{ role = "user"; text = "Okay recommend something with vanilla anyway" }
    )),
    (New-Scenario "P50V2-038" "What is the difference between Eau de Parfum and Eau de Toilette? No product cards" @{}),
    (New-Scenario "P50V2-049" "I want something that smells like Batman Black perfume" @{}),
    (New-Scenario "S-franco" "3ayz perfume fawa7 bs mesh t2eel w yenfa3 lel seif" @{ season = "summer"; intensity = "strong" }),
    (New-Scenario "S-reset-mother" "Forget all that. I want a gift for my mother under 700" @{ gender = "women"; occasion = "gift"; maxBudget = 700 })
  )
}

function Test-Mojibake([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  return $Text -match "[\u00D0\u00D8\u00D9\u00C3\u00E2\u0429\uFFFD]" -or
    $Text.Contains("????")
}

function Invoke-Scenario($scenario) {
  $requestId = [guid]::NewGuid().ToString()
  $body = @{
    currentMessage = $scenario.currentMessage
    preferences = $scenario.preferences
    candidates = New-Candidates
    responseLanguage = $ResponseLanguage
    requestId = $requestId
    sessionKey = "guest-cli-$Mode"
    recentMessages = if ($scenario.recentMessages) { $scenario.recentMessages } else { @(@{ role = "user"; text = $scenario.currentMessage }) }
    lastAssistantQuestion = $scenario.lastAssistantQuestion
    lastAskSlot = $scenario.lastAskSlot
    lastVisibleProductIds = @()
    conversationContext = @{
      hasRecommendationContext = $false
      hasAvailabilityContext = $false
      lastTurnWasAsk = [bool]$scenario.lastAssistantQuestion
    }
  }

  $started = Get-Date
  try {
    $response = Invoke-RestMethod `
      -Method Post `
      -Uri "$WorkerUrl/api/chat" `
      -ContentType "application/json; charset=utf-8" `
      -Body ($body | ConvertTo-Json -Depth 20) `
      -TimeoutSec 120

    $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
    $metadata = $response.metadata
    $commands = @($response.commands | ForEach-Object { $_.action })
    $productIds = @()
    foreach ($command in @($response.commands)) {
      foreach ($id in @($command.productIds)) { if ($id) { $productIds += [string]$id } }
    }
    foreach ($rec in @($response.recommendations)) {
      if ($rec.productId) { $productIds += [string]$rec.productId }
    }
    $productIds = @($productIds | Select-Object -Unique)

    $issues = @()
    if ($response.schemaVersion -ne 2) { $issues += "schema_not_v2" }
    if ($metadata.promptVersion -ne "chat_v2_structured_commands") { $issues += "prompt_not_v2" }
    if (-not $metadata.provider) { $issues += "missing_provider" }
    if (-not $metadata.modelId) { $issues += "missing_model" }
    if ($ResponseLanguage -eq "ar" -and (Test-Mojibake ([string]$response.message))) {
      $issues += "mojibake_message"
    }

    return [ordered]@{
      id = $scenario.id
      ok = ($issues.Count -eq 0)
      issues = $issues
      durationMs = $durationMs
      schemaVersion = $response.schemaVersion
      type = $response.type
      message = $response.message
      promptVersion = $metadata.promptVersion
      provider = $metadata.provider
      modelId = $metadata.modelId
      commandActions = $commands
      productIds = $productIds
      requestId = $requestId
    }
  } catch {
    return [ordered]@{
      id = $scenario.id
      ok = $false
      issues = @("http_error")
      error = $_.Exception.Message
      requestId = $requestId
    }
  }
}

$results = @()
foreach ($scenario in Get-Scenarios) {
  Write-Host "Running $($scenario.id)..." -ForegroundColor Cyan
  $result = Invoke-Scenario $scenario
  $results += $result
  ($result | ConvertTo-Json -Depth 20 -Compress) | Add-Content -Path $jsonlPath -Encoding UTF8
  $status = if ($result.ok) { "PASS" } else { "ISSUES: $($result.issues -join ',')" }
  Write-Host "  $status type=$($result.type) schema=$($result.schemaVersion) durationMs=$($result.durationMs)" -ForegroundColor $(if ($result.ok) { "Green" } else { "Yellow" })
}

$passed = @($results | Where-Object { $_.ok }).Count
$failed = $results.Count - $passed
$summary = @(
  "# Worker v2 CLI $Mode",
  "",
  "- Worker: $WorkerUrl",
  "- Response language: $ResponseLanguage",
  "- Total: $($results.Count)",
  "- Passed: $passed",
  "- With issues: $failed",
  "- JSONL: $jsonlPath",
  "",
  "## Issues"
)
foreach ($result in $results | Where-Object { -not $_.ok }) {
  $summary += "- `$($result.id)`: $($result.issues -join ', ')"
}
if ($failed -eq 0) {
  $summary += "- None"
}
$summary | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "Summary: $summaryPath" -ForegroundColor Cyan
Write-Host "JSONL: $jsonlPath" -ForegroundColor Cyan
if ($failed -gt 0) { exit 2 }
