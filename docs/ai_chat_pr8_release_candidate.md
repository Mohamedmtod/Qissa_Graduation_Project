# AI Chat PR8J Release Candidate

Date: 2026-05-24

## Scope

PR8J is validation and release decision only. It does not add features, change prompts, change ranking, or enable PR8 experimental flags by default.

## Automated validation

### Flutter static and targeted tests

```text
dart analyze lib/features/ai_chat test/features/ai_chat
Result: clean, no issues found.

ai_chat_cubit_test.dart: 112/112 passed.
ai_chat_worker_v2_pipeline_test.dart: 11/11 passed.
ai_chat_render_contract_test.dart: 2/2 passed.
catalog_facet_index_test.dart: 4/4 passed.
catalog_search_engine_test.dart: 7/7 passed.
catalog_query_service_test.dart: 5/5 passed.
suitability_policy_engine_test.dart: 6/6 passed.
ai_chat_tool_executor_test.dart: 4/4 passed.
```

### Worker

```text
npm test --prefix backend_and_cloud/workers/perfume-ai-chat-worker
Result: 48/48 passed.

node --check backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
Result: passed.
```

### Full AI Chat regression suite

```text
flutter test test/features/ai_chat --concurrency=1
Result: 597/597 passed.
```

## Smoke validation

### Worker live contract smoke

The live worker CLI smoke validates worker v2 contract and planning quality against the deployed worker. It does not replace Flutter guard/render validation.

```text
node --check ai_and_analytics_tools/ai_chat_worker_v2_cli_smoke.mjs
Result: passed.

node ai_and_analytics_tools/ai_chat_worker_v2_cli_smoke.mjs --mode GateMinus1 --response-language en --out-dir test_artifacts/live_gate_logs
Result: 1/1 strong, 0 blocking issues.
Artifact: test_artifacts/live_gate_logs/worker_v2_node_GateMinus1_20260523235256.md

node ai_and_analytics_tools/ai_chat_worker_v2_cli_smoke.mjs --mode Gate12 --response-language en --out-dir test_artifacts/live_gate_logs
Result: 12/12 strong, 0 blocking issues.
Artifact: test_artifacts/live_gate_logs/worker_v2_node_Gate12_20260523235317.md
```

### UI/staging smoke status

The requested 15-scenario UI smoke with dev/staging flags was not run in this workspace because it requires a configured app runtime, Firebase/device test environment, and deliberate staging flag setup.

Required staging flags for that smoke:

```text
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=true
AI_CHAT_USE_SUITABILITY_POLICY=true
AI_CHAT_TOOL_ROUTER_V1=true
AI_CHAT_SEND_COMPACT_CONTEXT=true
AI_CHAT_DELEGATE_MICRO_TURNS=true
```

If guest demo mode is used in staging only:

```text
AI_CHAT_ALLOW_GUEST_WORKER=true
```

Production defaults should not be changed based only on worker-only smoke.

## Release gates

Automated unit, headless pipeline, full AI Chat regression, and worker smoke results currently support these gates:

```text
No product hallucination: passed by guard/pipeline/regression coverage.
No fake price/business info: passed by grounding/business/cubit coverage.
No strict budget violation: passed by cubit, guard, worker, and regression coverage.
No allergy reversal: passed by grounding/cubit/regression coverage.
No external product rendered as card: passed by perfume knowledge and full suite coverage.
No permission-denied shown to user: covered by repo hardening tests and documented PR8I fallback behavior.
No raw worker/network error shown to user: covered by worker_timeout repo test and fallback pipeline coverage.
Invalid tool_call never renders: covered by validator, repo, executor, and pipeline tests.
```

Remaining gate requiring staging UI smoke before enabling beta flags broadly:

```text
No unsuitable cards for clear use-case when better alternatives exist.
```

This is covered by `suitability_policy_engine_test.dart`, `ai_chat_cubit_test.dart`, and headless pipeline tests, but should still be confirmed in a real app smoke with:

```text
recommend a perfume for a university -> for men
fresh clean daily -> men
gym perfume
office perfume
premium perfume without budget
```

## Release decision

PR8 is accepted as a conservative Production MVP Candidate with the new PR8 runtime flags kept off by default.

Recommended production defaults:

```text
ENFORCE_AUTH=true
AI_CHAT_ALLOW_GUEST_WORKER=false
AI_CHAT_TOOL_ROUTER_V1=false
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=false
AI_CHAT_USE_SUITABILITY_POLICY=false
AI_CHAT_CATALOG_SEARCH_SHADOW=false
```

Recommended staging/beta rollout:

```text
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=true
AI_CHAT_USE_SUITABILITY_POLICY=true
AI_CHAT_TOOL_ROUTER_V1=false
```

Advanced beta only after the full 15-scenario app smoke passes:

```text
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=true
AI_CHAT_USE_SUITABILITY_POLICY=true
AI_CHAT_TOOL_ROUTER_V1=true
```

## Known follow-ups

- Run the 15-scenario app/UI smoke in a configured staging environment before enabling PR8 flags broadly.
- Review `npm audit` findings separately. The worker dependency tree currently reports 6 vulnerabilities after local install; do not run `npm audit fix` inside PR8J without a separate dependency review and worker regression pass.
- No commit was created because this workspace does not expose a `.git` repository.

## Post-RC Targeted Hotfix And PR8K/L/N Slice

Date: 2026-05-25

After PR8J, a focused staging smoke exposed one real routing issue: product-context questions could still be interpreted as a new recommendation path in some cases. A targeted hotfix plus a small PR8K/PR8L/PR8N slice was applied without changing production defaults or worker prompts.

### Behavior now covered

```text
Explicit product context question:
is Light Blue suitable for work?
-> local text answer only
-> no recommendation cards
-> no worker recommendation call

Ambiguous visible product reference:
is it suitable for work?
-> focused clarification with visible product names
-> no random product assumption

Clarification answer:
3 / acqua
-> local answer for the selected visible product
-> no new cards

Visible ordinal follow-up:
does the first one work for office?
-> local answer for the first visible card
-> no new cards

Direct Arabic catalog query:
أغلى عطر عندك
-> local catalog query before /api/interpret
-> guarded catalog cards allowed
```

### Implementation notes

- `RouteDecision` trace fields are now used for product-context and catalog-query decisions: `action`, `shouldRenderCards`, `decisionOwner`, `clarificationType`, and `finalProductIds`.
- Decision trace now also includes `normalizedMessage` for later pattern analysis.
- Suitability policy now treats normal context mismatches as ranking penalties, not hard blocks.
- Suitability hard blocks are reserved for real safety/rendering constraints such as inactive/out-of-stock and excluded or medical-excluded notes.
- User-facing recommendation reasons are sanitized so raw internal codes such as `Suitability:` and snake_case reason codes do not appear in visible card copy.

### Post-RC validation

```text
dart analyze lib/features/ai_chat test/features/ai_chat
Result: clean, no issues found.

ai_chat_cubit_test.dart: 117/117 passed.
ai_chat_worker_v2_pipeline_test.dart: 12/12 passed.
ai_chat_render_contract_test.dart: 2/2 passed.
catalog_query_service_test.dart: 5/5 passed.
suitability_policy_engine_test.dart: 9/9 passed.
final_recommendation_guard_test.dart: 16/16 passed.
```

### Updated rollout note

PR8 remains a conservative Production MVP Candidate. The post-RC changes make staging/beta validation safer, but they do not justify enabling PR8 flags in production without the full UI smoke and rollout decision.
