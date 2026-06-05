# AI Chat Debug, Testing, and Improvement Operations

Last updated: 2026-06-06

This document records the current AI Chat validation and debugging system so future agents can test, diagnose, improve, and maintain the chat without guessing.

## Current Goal

The AI Chat is being prepared for controlled internal/staging use, not broad production rollout. The target is:

- Natural language goes through the semantic/LLM route.
- Local handling only claims deterministic proof.
- Dart guards enforce catalog truth, product IDs, prices, stock, cards, budget, allergy, and external-product safety.
- Final copy is customer-facing and does not leak internal reason codes.
- Any bad chat can be reviewed by `chatDebugId` using sanitized D1 debug data.

## Current AI Chat Status

Recent validation has closed these workstreams:

| Area | Status | Notes |
|---|---|---|
| PR14C-2 Debug Sessions | PASS | D1 debug storage by `chatDebugId` exists. |
| PR14E Retrieval Scripts | PASS | Scripts can fetch chat and feedback context. |
| PR14G Retention Cleanup | PASS | Cleanup script exists, dry-run by default, remote dry-run passed. |
| PR15 Route Ownership | PASS | Flag-gated ownership cleanup validated with targeted, legacy, and Android E2E when device was available. |
| PR16 Stability | PASS | Runtime/scenario stabilization completed before PR17/PR18. |
| PR17 Latency Guard | PASS | Worker deployed and real smoke passed, `over15s=0` in smoke. |
| PR18 Copy Polish | PASS | Targeted copy validation passed; Android UI smoke was blocked by missing device at the time. |
| PR23 Route Ownership | PASS | App-side route ownership tightened; 30-run route/safety validation passed. |
| PR23R Reporting | PASS | 30-run now writes persistent `summary.md` and `results.json` from the current run. |
| PR24/PR24.1 Latency/Friction | PASS | Latest real emulator 30-run has `over15s=0`, `avgLatencyMs ~= 5761`, D1 `30/30`. |
| PR25 Action Policy | PASS | One-card final pick, sensitive-skin recommendation, and answer-only size advice validated in real 30-run. |
| PR26 Supplemental 31-60 Suite | PASS | Supplemental scenarios were added and validated separately before being merged into a unified run. |
| PR27 Supplemental UX Fixes + 60-run | PASS | Real Android emulator + real worker + D1 validated S01-S60 with P0 `0`, D1 `60/60`, and `over15sTurnCount=0`. |

Latest real emulator + D1 validation baseline:

```text
Artifact: test_artifacts/ai_chat_real_emulator_60/20260605_205624
S01-S60 scenarios: PASS
D1 readable sessions: 60/60
P0: 0
P1: 0
over15sTurnCount: 0
avgLatencyMs: ~5956
p95LatencyMs: ~9900
p95TurnLatencyMs: ~7386
maxTurnLatencyMs: ~14154
P2 watch items: S08 and S45 latency above 10s but below 15s
```

Previous 30-run baseline remains useful for comparison:

```text
Artifact: test_artifacts/ai_chat_real_emulator_30/20260605_100813
30/30 scenarios: PASS
D1 readable sessions: 30/30
P0: 0
P1: 0
over15sTurnCount: 0
avgLatencyMs: ~5761
P2: S16 external similarity latency slightly above 10s
```

Approximate current quality estimate after PR27/60-run validation:

| Dimension | Estimated Score | Notes |
|---|---:|---|
| Catalog safety | 97-100% | External product cards, fake product IDs, fake price/stock, and mojibake were all `0` in the 60-run. |
| Routing/action safety | 95-97% | S31-S60 route/action caveats were fixed and S01-S60 stayed clean. |
| D1 observability | 100% | Latest run had D1 readable sessions `60/60`. |
| Copy quality | ~90% | Safe and non-generic in the 60-run; real-user tone still needs observation. |
| Latency | 90-92% | No turn over 15s; S08/S45 remain P2 watch items above 10s. |
| Overall internal readiness | 94-96% | Ready for internal/staging observation. |
| Broad production readiness | 87-90% | Needs real-user observation before broad rollout. |

These percentages are engineering estimates based on targeted tests, legacy audits, mocked suites, and selected real-backend smoke. They are not production analytics.

## Internal/Staging Observation Run

Do not start PR22 cleanup, broad feature work, deploys, D1 schema changes, or Firestore changes during this phase. The goal is to observe real chat behavior with `chatDebugId` and decide future fixes from evidence.

Recommended duration and sample size:

```text
Duration: 24-72 hours
Conversations: 10-30 real chats
Participants: different internal/staging testers when possible
```

Use an internal/staging build with the flags below. `AI_CHAT_DEBUG_CAPTURE_MODE=all` is acceptable only for internal/staging observation. Later limited production should use `feedback_only` or sampling.

For every test conversation, record:

```text
chatDebugId
tester/person label, optional
scenario label
good / suspicious / bad
short notes
feedbackId, if the tester pressed feedback
```

Use this lightweight table format:

```text
chatDebugId | tester | scenario | result | notes | feedbackId
chat_dbg_xxx | tester-a | external similarity | suspicious | slow but safe |
chat_dbg_yyy | tester-b | gift recommendation | good | good cards and copy |
```

Cover these conversation types:

```text
social / short replies
recommendations
budget
notes
external similarity
availability
rejection / cheaper follow-up
gift / sensitive occasions
memory follow-up
business questions
```

For any suspicious or bad response, fetch the D1 debug transcript:

```powershell
node testing_tools\ai_chat_debug\get_chat_debug.mjs --chat-debug-id chat_dbg_xxx
```

If the report includes a feedback ID:

```powershell
node testing_tools\ai_chat_debug\get_feedback_context.mjs --feedback-id fb_xxx
```

Monitor and classify:

| Severity | Examples | Decision |
|---|---|---|
| P0 | fake product/card/price/stock, external perfume rendered as card, mojibake, social/short turns asking gender, `no_match` with candidates, missing D1 debug for a reported chat | Stop rollout; fix via a small PR based on the exact `chatDebugId`. |
| P1 | latency over 15s, clear wrong route, over-clarification blocking recommendation, slow/confusing external similarity, meaningful memory loss | Staging only; fix by recurrence and impact. |
| P2 | safe but unimpressive copy, safe but imperfect recommendation, catalog/note gap, one-off 10-15s latency | Track and batch into small polish/data PRs. |

Daily review checklist:

```text
latency > 10s
latency > 15s
external similarity delays
over-clarification
wrong recommendation
catalog gap
memory issues
generic copy
mojibake
fake product/price/stock
external product cards
D1 missing turns
```

Decision after observation:

```text
If P0 = 0, P1 is low/understood, and every reported chat has readable D1 debug:
  AI Chat can continue to limited staging/pilot.

If any P0 appears:
  Do not roll out. Open a small PR based on the exact chatDebugId.

If P1/P2 repeats:
  Prioritize fixes by recurrence:
  1. external similarity latency/copy
  2. over-clarification
  3. catalog/note coverage
  4. memory follow-up
  5. empathy/copy polish
```

## Readiness Gate For The Next 30 Scenarios

Do not add the next supplemental 30 scenarios until the internal/staging observation has enough real evidence. The next suite can start when:

```text
10-30 real internal/staging chats were reviewed
every suspicious/bad chat has a readable chatDebugId
P0 = 0
no repeated P1, such as latency >15s or a clear wrong route
S08/S45-style latency does not repeat in real chats, or remains only a P2 watch item
```

If a P0 or repeated P1 appears during observation, pause the new suite and open one small PR based on the exact `chatDebugId`.

When the user provides the next 30 scenarios, treat them as a separate suite first:

```text
suiteName: ai_chat_supplemental_61_90
artifactRoot: test_artifacts/ai_chat_supplemental_61_90/<timestamp>/
do not merge into mandatory baseline immediately
```

Before running, normalize the scenario text as UTF-8 and reject mojibake in Arabic previews. Each scenario should have:

```text
id
messages
expectedIntent
expectedCards
focus
```

Run order:

```text
1. preflight: 2 scenarios
2. subset: 5-8 varied scenarios
3. full new 30
4. if clean or triaged, unified S01-S90 run
```

Acceptance for the new 30:

```text
D1 readable sessions = 30/30
P0 = 0
fake IDs/cards/price/stock = 0
mojibake = 0
external product card violations = 0
over15sTurnCount = 0
every P1/P2 has a chatDebugId and root-cause label
```

Acceptance for the later unified S01-S90 run:

```text
D1 readable sessions = 90/90
P0 = 0
over15sTurnCount = 0
baseline S01-S60 does not regress
```

## Cleanup Hold

Do not start PR22 cleanup until after internal/staging observation. The current AI Chat still has fallback paths that may only appear in real use. Cleanup is allowed only after:

```text
10-30 real chats reviewed
reported chatDebugIds are readable
no rare useful fallback branch appears in observation
```

When cleanup begins, keep it narrow:

```text
remove/merge only branches proven unused or duplicate
keep safety/catalog/availability/fallback guards
run targeted tests plus a 30-run smoke
```

## Required Flags For Internal/Staging Observation

Use these for real internal/staging chat testing:

```text
AI_CHAT_DETERMINISTIC_GATE_V1=true
AI_CHAT_LLM_LED_ROUTER_V2=true
AI_CHAT_ANALYTICS_EVENTS_ENABLED=true
AI_CHAT_TURN_DEBUG_REMOTE_ENABLED=true
AI_CHAT_DEBUG_CAPTURE_MODE=all
AI_CHAT_ANALYTICS_REMOTE_SINK_ENABLED=false
```

For later limited production, prefer:

```text
AI_CHAT_DETERMINISTIC_GATE_V1=true
AI_CHAT_LLM_LED_ROUTER_V2=true
AI_CHAT_ANALYTICS_EVENTS_ENABLED=true
AI_CHAT_TURN_DEBUG_REMOTE_ENABLED=true
AI_CHAT_DEBUG_CAPTURE_MODE=feedback_only
AI_CHAT_ANALYTICS_REMOTE_SINK_ENABLED=false
```

Important rollback guidance:

- If Router V2 causes routing issues: set `AI_CHAT_LLM_LED_ROUTER_V2=false`.
- Keep `AI_CHAT_DETERMINISTIC_GATE_V1=true` unless a specific gate regression is proven.
- Do not use gate-off as the main rollback for production UX, because previous smoke showed worse social/natural-language behavior with gate off.

## Debug IDs

Each AI Chat session has a safe identifier:

```text
chat_dbg_xxxxxxxxxx
```

The UI can copy this ID. A tester should send the `chatDebugId` when reporting a bad chat.

With the ID, an agent can review a sanitized ordered conversation:

- User message preview, redacted.
- Assistant reply preview, redacted.
- Route/action/source.
- Tool name/status.
- Render intent.
- Worker/fallback usage.
- Latency.
- Product IDs, capped.
- Feedback reason if present.

The debug system must not store or expose:

- prompts
- full prompts
- raw model input/output
- raw user ID
- raw session ID
- secrets
- API keys/tokens
- full private transcripts

## D1 Debug Database

Current D1 database:

```text
qissa_ai_chat_debug
```

Current tables:

```text
ai_chat_debug_sessions
ai_chat_debug_turns
ai_chat_feedback_debug
```

Worker binding is configured in:

```text
backend_and_cloud/workers/perfume-ai-chat-worker/wrangler.toml
```

Migration source:

```text
backend_and_cloud/workers/perfume-ai-chat-worker/migrations/0001_ai_chat_debug.sql
```

Do not edit D1 schema, run migrations, deploy workers, or delete data without explicit same-message approval.

## Retrieval Scripts

Scripts live in:

```text
testing_tools/ai_chat_debug/
```

### Read A Chat By ID

```powershell
node testing_tools\ai_chat_debug\get_chat_debug.mjs --chat-debug-id chat_dbg_xxx
```

Use this when a tester says:

```text
This chat had a problem: chat_dbg_xxx
```

The output should tell the agent the ordered story:

```text
Turn 1
User: ...
Assistant: ...
Route: ...
Source: ...
Tool: ...
Products: ...
Latency: ...
```

### Read Feedback Context

```powershell
node testing_tools\ai_chat_debug\get_feedback_context.mjs --feedback-id fb_xxx
```

This is useful when the user pressed negative feedback and sent the feedback ID.

### List Recent Bad Feedback

```powershell
node testing_tools\ai_chat_debug\list_bad_feedback.mjs --limit 20
```

Use this to find recent bad feedback rows, then fetch context by feedback/chat ID.

## Retention Cleanup

Cleanup script:

```text
testing_tools/ai_chat_debug/cleanup_debug_logs.mjs
```

Default retention policy:

| Data | Retention |
|---|---:|
| Debug turns | 30 days |
| Feedback debug | 90 days |
| Orphan sessions | 90 days |

Dry-run is the default and does not delete:

```powershell
node testing_tools\ai_chat_debug\cleanup_debug_logs.mjs --turn-days 30 --feedback-days 90
```

Last confirmed remote dry-run result:

```text
debugTurnsEligible: 0
feedbackRowsEligible: 0
orphanSessionsEligible: 0
```

Actual deletion requires `--write` and explicit approval in the same message:

```powershell
node testing_tools\ai_chat_debug\cleanup_debug_logs.mjs --turn-days 30 --feedback-days 90 --write
```

Never run `--write` automatically.

## Recommended Staging Run

Run 10-30 real or semi-real internal chats with the staging flags above. For each chat, record:

```text
chatDebugId | scenario | result | notes
```

Example:

```text
chat_dbg_x1 | social | good | no cards, no gender ask
chat_dbg_x2 | mango note | suspicious | latency high
chat_dbg_x3 | Dior Sauvage | good | catalog-only cards
```

Recommended scenarios:

1. Social:
   - `how are you`
   - `عامل ايه`
2. Arabic ambiguity:
   - `رشحلي ريحة حلوة`
   - `جميلة ولطيفة`
3. Notes and refinement:
   - `is there with mango?`
   - `فيه حاجة فيها فانيليا؟`
   - `عايز حاجة فيها عود`
4. Exact availability:
   - `Do you have Light Blue?`
   - `عندك لايت بلو؟`
5. Visible products:
   - `which is cheapest among them?`
   - `which one is better?`
6. External references:
   - `Something like Dior Sauvage`
   - `Something like Sauvage`
   - `Blue`
   - `Bleu`
7. Rejection and cheaper:
   - `I don't like these`
   - `show me something cheaper`
8. Budget:
   - `under 600`
   - `ok show me it`
9. Vibe:
   - `عايز حاجة شيك ومش خانقة`
   - `عايز ريحة فنادق فخمة`
10. Product context:
   - `why Dior Sauvage is good?`
   - `is Light Blue good for work?`

## What To Review In Each Debug Session

Look for P0 problems:

- social turns routed to gender ask or availability
- note/vibe/refinement turns routed to availability without a product anchor
- external perfume rendered as a catalog product card
- fake price, stock, or availability
- fake product IDs
- mojibake
- `no_match` while valid candidates exist
- repeated products after explicit rejection
- broad external auto-pick, such as `Sauvage` silently becoming `Dior Sauvage`

Look for P1 problems:

- latency above 15 seconds
- latency near 10 seconds for simple note/refinement turns
- confusing or cold copy
- too many clarifications for specific requests
- worker type mismatch, such as availability typed as recommendation
- memory context loss
- same product IDs after refinement without explanation

## Test Commands

Run Flutter tests serially for AI Chat. Do not run Android/native-heavy integration tests in parallel.

### Targeted Copy And Guard Tests

```powershell
cd F:\Qissa_Graduation_Project\mobile_app
flutter test test\features\ai_chat\presentation\manager\final_recommendation_guard_test.dart
flutter test test\features\ai_chat\presentation\manager\ai_chat_response_copy_engine_test.dart
flutter test test\features\ai_chat\presentation\manager\availability_message_builder_test.dart
flutter test test\features\ai_chat\presentation\manager\ai_chat_copy_mojibake_test.dart
```

### PR15 Ownership / Legacy Audit

```powershell
cd F:\Qissa_Graduation_Project\mobile_app
flutter test test\features\ai_chat\presentation\manager\ai_chat_cubit_test.dart --dart-define=AI_CHAT_LLM_LED_ROUTER_V2=true
flutter test test\features\ai_chat\presentation\manager\ai_chat_legacy_488_scenario_bank_test.dart --dart-define=AI_CHAT_LLM_LED_ROUTER_V2=true
```

The legacy scenario bank should complete all `976/976` variants. Treat its output as a UX audit, not just pass/fail.

### Android E2E When Device Exists

Check devices first:

```powershell
flutter devices
```

Then run serially:

```powershell
cd F:\Qissa_Graduation_Project\mobile_app
flutter test integration_test\ai_chat_e2e_ui_smoke_test.dart --dart-define=AI_CHAT_DETERMINISTIC_GATE_V1=true --dart-define=AI_CHAT_LLM_LED_ROUTER_V2=true
flutter test integration_test\ai_chat_external_knowledge_e2e_test.dart --dart-define=AI_CHAT_DETERMINISTIC_GATE_V1=true --dart-define=AI_CHAT_LLM_LED_ROUTER_V2=true
```

If no Android device appears, report it as environment-blocked, not a code failure.

## Worker Checks

Before any worker deploy:

```powershell
cd F:\Qissa_Graduation_Project\backend_and_cloud\workers\perfume-ai-chat-worker
node --check src\index.js
npm test
npm audit --audit-level=high
```

Deploy commands require explicit same-message approval.

## Current Known Watch Items

- Some recommendation/note turns can still approach 10 seconds. PR17 capped worst-case latency, but UX can still be improved later with a carefully scoped soft timeout.
- `Do you have Light Blue?` can be safe but typed as `recommendation` in worker smoke. This is a W5 polish item if the worker endpoint needs stricter availability typing.
- Android UI smoke for PR18 was blocked when no Android device was available. Re-run when emulator/device is present.
- Copy is improved, but staging observation should still check whether replies feel persuasive, helpful, and natural.
- Do not add more features before staging observation unless a P0 is found.

## Rules For Future Agents

1. Start diagnosis from `chatDebugId` when available.
2. Use D1 retrieval scripts instead of guessing from screenshots.
3. Do not read raw Cloudflare/Firebase logs or private production data.
4. Do not store prompts or raw model input/output.
5. Keep AI Chat integration tests serial.
6. Do not run cleanup `--write` without explicit same-message approval.
7. Do not deploy workers without explicit same-message approval.
8. Prefer targeted fixes:
   - routing ownership issue -> PR15 area
   - latency issue -> worker latency policy
   - cold/internal copy -> PR18 copy area
   - D1/debug issue -> PR14 scripts/worker endpoint
9. Verify with the smallest relevant tests first.
10. Document any new watch item in this file or a linked follow-up report.
