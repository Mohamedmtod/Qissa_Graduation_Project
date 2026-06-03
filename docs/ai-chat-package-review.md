# AI Chat Package Review

This is a safe classification report only. No source code, database data, worker deployment, or generated artifacts were changed by this review.

## Summary

The AI Chat package is a large but coherent review package. It should be reviewed separately from PR11 Staff Taste and POS work.

Current targeted diff size for AI Chat mobile + AI worker:

```text
49 files changed, 7177 insertions(+), 4588 deletions(-)
```

The package combines:

- Mobile AI Chat tool contract cleanup.
- Async tool execution.
- Recommendation memory/context improvements.
- Guarded reply rendering.
- External perfume reference/profile support.
- Worker schema/config/test alignment.
- AI Chat unit, flow, and E2E tests.

## Keep In AI Chat Package

### Mobile source

```text
mobile_app/lib/features/ai_chat/core/ai_chat_config.dart
mobile_app/lib/features/ai_chat/core/ai_normalization_dictionary.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_reply.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_reply_validator.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_structured_reply.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_tool_call.dart
mobile_app/lib/features/ai_chat/data/models/recommendation_memory.dart
mobile_app/lib/features/ai_chat/data/repos/ai_chat_repo.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_context_followups.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_quality_guards.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_recommendation_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_turn_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_worker_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_local_catalog_command_handler.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_preference_change_detector.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_product_context_signals.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_session_actions.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_session_id_store.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_stored_message_restorer.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_result_renderer.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_worker_reply_service.dart
mobile_app/lib/features/ai_chat/presentation/manager/availability_intent_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/final_recommendation_guard.dart
mobile_app/lib/features/ai_chat/presentation/manager/local_intent_parser.dart
mobile_app/lib/features/ai_chat/presentation/manager/perfume_reference_resolver.dart
mobile_app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart
mobile_app/lib/features/ai_chat/presentation/widgets/recommended_product_card.dart
```

### Mobile tests

```text
mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart
mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart
mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart
mobile_app/test/features/ai_chat/data/models/ai_chat_reply_validator_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_capabilities_contract_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_conversational_fixes_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_conversational_policy_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_experiment_config_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_preference_change_detector_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_product_context_signals_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_resolver_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_runtime_utils_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_smoke_scenarios_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_social_gender_regression_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart
mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart
mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart
mobile_app/test/features/ai_chat/presentation/widgets/recommended_product_card_test.dart
```

### AI worker

```text
backend_and_cloud/workers/perfume-ai-chat-worker/package.json
backend_and_cloud/workers/perfume-ai-chat-worker/package-lock.json
backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js
backend_and_cloud/workers/perfume-ai-chat-worker/wrangler.toml
```

Risk note: worker files are backend/cloud sensitive-zone files. They should be reviewed separately from mobile code before any deploy.

## Keep Out Of AI Chat Core Package

These files live under AI Chat paths but belong to PR11 Staff Taste, not the core AI Chat production-readiness package:

```text
mobile_app/lib/features/ai_chat/core/staff_taste_taxonomy.dart
mobile_app/lib/features/ai_chat/presentation/manager/staff_taste_scorer.dart
mobile_app/test/features/ai_chat/presentation/manager/staff_taste_scorer_test.dart
mobile_app/test/features/ai_chat/presentation/manager/staff_taste_shadow_validation_test.dart
```

Related tracked staff-taste changes should also remain in the PR11 package:

```text
mobile_app/lib/features/ai_chat/presentation/manager/catalog_facet_index.dart
mobile_app/lib/features/ai_chat/presentation/manager/suitability_policy_engine.dart
mobile_app/test/features/ai_chat/presentation/manager/catalog_facet_index_test.dart
mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart
```

## Defer / Do Not Include

```text
mobile_app/lib/features/ai_chat.zip
```

Reason: local archive artifact. Do not delete without explicit approval, but do not include in the AI Chat source package.

## Review Risks

- `ai_chat_tool_executor.dart` is a very large change and should receive focused review.
- `ai_chat_cubit.dart` shrank significantly, which is good for separation, but the extracted untracked files must be included together or imports will break.
- Worker package dependency/config changes require backend/cloud review.
- `wrangler.toml` should not be treated as deploy approval.
- Release logging behavior should be checked in `ai_chat_repo.dart` before production.
- E2E files are untracked and must be included with the package if this work is committed later.

## Recommended Validation Before Packaging

Mobile:

```powershell
cd F:\Qissa_Graduation_Project\mobile_app
flutter analyze
flutter test
flutter test integration_test\ai_chat_e2e_ui_smoke_test.dart
flutter test integration_test\ai_chat_external_knowledge_e2e_test.dart
```

Worker:

```powershell
cd F:\Qissa_Graduation_Project\backend_and_cloud\workers\perfume-ai-chat-worker
node --check src\index.js
npm test
npm audit --audit-level=moderate
```

## Decision

AI Chat is suitable to become the first isolated review package, but it must include its new untracked manager/test files. Staff taste files and the zip artifact should stay out of this package.
