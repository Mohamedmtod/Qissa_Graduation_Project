# AI Chat Debug, Testing, and Improvement Operations

Last updated: 2026-06-03

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

Approximate current quality estimate after PR18 targeted validation:

| Dimension | Estimated Score | Notes |
|---|---:|---|
| Catalog safety | 95%+ | External product cards and fake product IDs guarded. |
| Routing safety | 92-94% | Local deterministic vs semantic ownership is much cleaner with flags on. |
| Copy quality | 86-88% | Better, but still needs staging observation. |
| Latency | 75-80% | Worst-case improved, but not always fast/impressive. |
| Overall AI Chat readiness | 90-91% | Candidate for internal/staging observation, not broad production. |

These percentages are engineering estimates based on targeted tests, legacy audits, mocked suites, and selected real-backend smoke. They are not production analytics.

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

