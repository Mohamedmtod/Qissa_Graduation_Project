# Working Tree Cleanup Report

Generated for safe classification only. This report does not imply approval to delete, revert, deploy, migrate, or patch production data.

## Summary

The working tree is intentionally dirty and currently mixes several independent work packages:

- AI Chat production-readiness and tool-contract cleanup.
- PR11 staff taste/admin foundation.
- POS admin/worker foundation.
- Backend worker/rules verification changes.
- Docs, testing tools, and generated/local artifacts.

No debug logs, secrets, dumps, or production data were read while preparing this report.

## Snapshot

Read-only commands used:

```text
git status --short
git diff --stat
git diff --name-status
git ls-files --others --exclude-standard
```

Current tracked diff summary:

```text
75 files changed, 9422 insertions(+), 5177 deletions(-)
```

Main tracked change areas:

- `admin_dashboard/`: staff taste/admin UI, inventory model/repo/service, shell/router, POS-adjacent admin navigation, i18n.
- `backend_and_cloud/`: Firestore rules/tests, AI chat worker dependency/schema/config/test updates, orders worker minor change.
- `mobile_app/`: AI Chat tool flow, memory/context, reply handling, guards, product model, staff taste, cart/categories/UI-adjacent changes, tests.

Main untracked areas:

- `admin_dashboard/lib/features/pos/`
- `backend_and_cloud/workers/perfume-pos-worker/`
- `docs/pos/`
- AI Chat docs/tests/new manager services.
- Staff taste taxonomy/scorer/tests/tooling.
- Debug logs and local generated artifacts.

## Sensitive / Deferred Files Not Read

These files are untracked and must not be read, printed, summarized, or deleted without explicit same-message approval:

```text
backend_and_cloud/firebase-debug.log
backend_and_cloud/firestore-debug.log
testing_tools/firebase-debug.log
testing_tools/firestore-debug.log
```

These files are local artifacts or generated outputs and should be classified before any cleanup:

```text
mobile_app/lib/features/ai_chat.zip
testing_tools/cataloge.json
testing_tools/staff_taste_preview.json
testing_tools/staff_taste_preview_80.json
testing_tools/staff_taste_preview_all.json
testing_tools/staff_taste_verify_1.json
testing_tools/staff_taste_verify_all.json
testing_tools/staff_taste_write_1_preview.json
testing_tools/tool/staff_taste_firestore_patch.mjs
```

## Package Classification

### 1. AI Chat Production-Readiness Package

Status: keep as one review package.

Purpose:

- Async tool execution.
- Safe handlers for previously allowed/unimplemented tools.
- `update_preferences_and_recommend` runs recommendation after applying preference patches.
- External profile/reference resolver support.
- Compact context and recommendation memory improvements.
- Guarded rendering and reply/copy cleanup.
- AI Chat unit, flow, and E2E tests.

Tracked files to keep in this package:

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
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_recommendation_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_turn_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_worker_flow.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_runtime_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_session_actions.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_worker_reply_service.dart
mobile_app/lib/features/ai_chat/presentation/manager/availability_intent_utils.dart
mobile_app/lib/features/ai_chat/presentation/manager/final_recommendation_guard.dart
mobile_app/lib/features/ai_chat/presentation/manager/local_intent_parser.dart
mobile_app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart
mobile_app/lib/features/ai_chat/presentation/widgets/recommended_product_card.dart
```

Untracked files to keep in this package:

```text
mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart
mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_business_info_responder.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_context_followups.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_quality_guards.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_local_catalog_command_handler.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_preference_change_detector.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_product_context_signals.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_session_id_store.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_stored_message_restorer.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_result_renderer.dart
mobile_app/lib/features/ai_chat/presentation/manager/perfume_reference_resolver.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_capabilities_contract_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_preference_change_detector_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_product_context_signals_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver_test.dart
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_smoke_scenarios_test.dart
mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart
```

Needs decision before final split:

- `mobile_app/lib/features/ai_chat.zip` should not be part of source unless it is an intentional review artifact.
- `mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_state.dart` shows tracked changes; inspect whether this is intentional cleanup or leftover state removal before packaging.

### 2. PR11 Staff Taste Package

Status: keep as separate PR11 review package.

Purpose:

- Staff taste taxonomy.
- Staff fields in product/admin models.
- Staff quick tagging/admin review flow.
- Staff scorer shadow behavior.
- Generated data guard.

Tracked files to keep in this package:

```text
admin_dashboard/assets/i18n/ar.json
admin_dashboard/assets/i18n/en.json
admin_dashboard/lib/features/admin/data/models/admin_inventory_item.dart
admin_dashboard/lib/features/admin/data/repos/admin_inventory_repository.dart
admin_dashboard/lib/features/admin/data/services/admin_firestore_inventory_service.dart
admin_dashboard/lib/features/admin/data/services/admin_inventory_service.dart
admin_dashboard/lib/features/admin/presentation/manager/admin_inventory_cubit.dart
admin_dashboard/lib/features/admin/presentation/pages/inventory_page.dart
admin_dashboard/lib/features/admin/presentation/widgets/admin_product_editor_dialog.dart
mobile_app/lib/features/ai_chat/core/staff_taste_taxonomy.dart
mobile_app/lib/features/ai_chat/presentation/manager/catalog_facet_index.dart
mobile_app/lib/features/ai_chat/presentation/manager/suitability_policy_engine.dart
mobile_app/lib/features/products/data/models/product_model.dart
mobile_app/test/features/ai_chat/presentation/manager/catalog_facet_index_test.dart
mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart
mobile_app/test/features/products/data/models/product_model_test.dart
```

Untracked files to keep in this package:

```text
admin_dashboard/lib/features/admin/data/models/staff_taste_intelligence.dart
mobile_app/lib/features/ai_chat/core/staff_taste_taxonomy.dart
mobile_app/lib/features/ai_chat/presentation/manager/staff_taste_scorer.dart
mobile_app/test/features/ai_chat/presentation/manager/staff_taste_scorer_test.dart
mobile_app/test/features/ai_chat/presentation/manager/staff_taste_shadow_validation_test.dart
```

Needs decision before final split:

- Staff taste preview/write JSON files in `testing_tools/` are generated/tooling artifacts. Keep only if they are intentionally documented fixtures.
- `testing_tools/tool/staff_taste_firestore_patch.mjs` is a database-writing tool and should remain deferred unless explicitly approved.

### 3. POS Package

Status: keep as separate POS review package.

Purpose:

- Admin POS UI/state.
- POS local/remote repository/service layer.
- POS worker foundation.
- POS docs and API contracts.

Untracked POS files:

```text
admin_dashboard/lib/features/pos/
backend_and_cloud/workers/perfume-pos-worker/
docs/pos/
```

Tracked POS-adjacent files requiring review:

```text
admin_dashboard/lib/bootstrap.dart
admin_dashboard/lib/core/router/app_router.dart
admin_dashboard/lib/features/admin/presentation/pages/admin_shell.dart
backend_and_cloud/workers/perfume-orders-worker/src/index.js
```

Risk:

- POS touches admin app and backend/cloud worker code.
- No deploy should happen from this cleanup.
- POS worker secrets/config must not be read or inferred from local private files.

### 4. Backend / Rules / Worker Package

Status: keep as sensitive-zone package.

Purpose:

- AI chat worker dependency/config/schema alignment.
- Worker test/audit cleanup.
- Firestore rules tests and limited rules compatibility changes.

Files:

```text
backend_and_cloud/functions/firestore.rules.test.js
backend_and_cloud/rules/firestore.rules
backend_and_cloud/workers/perfume-ai-chat-worker/package-lock.json
backend_and_cloud/workers/perfume-ai-chat-worker/package.json
backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js
backend_and_cloud/workers/perfume-ai-chat-worker/wrangler.toml
```

Risk:

- `package-lock.json` and `package.json` mean dependency changes.
- `wrangler.toml` is deployment/runtime configuration.
- `firestore.rules` changes can affect app/admin access.
- This package requires focused review before any production deployment.

### 5. Docs / Tooling Package

Status: keep/review separately.

Files:

```text
.gitignore
AGENTS.md
docs/AI_CHAT_STRUCTURE_AND_FLOW.md
docs/ai-chat-structure-and-flow.md
docs/implementation_plan.md
docs/working-tree-cleanup-report.md
```

Artifacts/defer:

```text
mobile_app/lib/features/ai_chat.zip
testing_tools/cataloge.json
testing_tools/staff_taste_preview*.json
testing_tools/staff_taste_verify*.json
testing_tools/staff_taste_write_1_preview.json
```

Risk:

- `.gitignore` is currently very small and does not ignore debug logs, zip artifacts, or staff taste generated previews.
- Expanding `.gitignore` would be a separate, low-risk cleanup change, but it is still a repository change and should be reviewed.

## High-Risk Change Review

### Backend/cloud worker config

Files:

```text
backend_and_cloud/workers/perfume-ai-chat-worker/wrangler.toml
backend_and_cloud/workers/perfume-ai-chat-worker/package.json
backend_and_cloud/workers/perfume-ai-chat-worker/package-lock.json
backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
```

Review requirements:

- Confirm dependency update was intentional.
- Confirm no secrets are embedded.
- Confirm production origins/config are explicit.
- Confirm no deploy was run.

### Firestore rules

Files:

```text
backend_and_cloud/rules/firestore.rules
backend_and_cloud/functions/firestore.rules.test.js
```

Review requirements:

- Confirm changes are compatibility/test focused.
- Confirm no broad hardening or permission expansion happened unintentionally.
- Run rules tests from a clean emulator port before merge.

### Admin review workflow

Files:

```text
admin_dashboard/lib/features/admin/data/models/admin_inventory_item.dart
admin_dashboard/lib/features/admin/data/repos/admin_inventory_repository.dart
admin_dashboard/lib/features/admin/data/services/admin_firestore_inventory_service.dart
admin_dashboard/lib/features/admin/presentation/widgets/admin_product_editor_dialog.dart
```

Review requirements:

- Confirm normal staff edits set review-needed state.
- Confirm main-admin approval logic is app-side only unless rules later enforce it.
- Confirm generated staff data does not become trusted in AI ranking.

### Generated staff data tooling

Files:

```text
testing_tools/tool/staff_taste_firestore_patch.mjs
testing_tools/staff_taste_*.json
```

Review requirements:

- Treat as deferred.
- Do not run without explicit same-message approval.
- Do not patch Firestore during cleanup.

## Validation Matrix

### AI Chat package

Recommended checks before finalizing the package:

```powershell
cd F:\Qissa_Graduation_Project\mobile_app
flutter analyze
flutter test
flutter test integration_test\ai_chat_e2e_ui_smoke_test.dart
flutter test integration_test\ai_chat_external_knowledge_e2e_test.dart
```

### Admin / PR11 package

Recommended checks:

```powershell
cd F:\Qissa_Graduation_Project\admin_dashboard
flutter analyze
```

If admin tests are added or present, run the targeted staff taste/admin inventory tests as well.

### Backend / rules / AI worker package

Recommended checks:

```powershell
cd F:\Qissa_Graduation_Project\backend_and_cloud\workers\perfume-ai-chat-worker
node --check src\index.js
npm test
npm audit --audit-level=moderate
```

Firestore rules should be checked from the expected rules/functions setup. If using emulator port `8085`, ensure no existing emulator is occupying the port before running the wrapper command.

### POS package

Recommended checks:

```powershell
cd F:\Qissa_Graduation_Project\backend_and_cloud\workers\perfume-pos-worker
npm test
node --check src\index.js
```

Admin POS checks should be run through the admin dashboard analyze/test path after the POS package is reviewed.

## Recommended PR Split

1. `AI Chat production-readiness and tool contract cleanup`
   - Mobile AI Chat code, AI worker schema alignment, AI Chat tests/E2E.

2. `PR11 staff taste foundation`
   - Staff taxonomy, ProductModel/admin fields, quick tagging UI, shadow scorer, staff tests.

3. `POS foundation`
   - Admin POS UI/state, POS worker, POS docs.

4. `Backend/rules verification`
   - Firestore rules/tests, worker dependency/config validation, no deployment.

5. `Docs/tooling cleanup`
   - AGENTS, structure docs, implementation notes, `.gitignore`, generated artifact decisions.

## Explicitly Deferred

These actions are not part of this cleanup and require explicit approval later:

- Delete debug logs.
- Delete zip/artifact files.
- Revert unrelated changes.
- Run `git reset`, `git clean`, or `rm`.
- Firestore data hygiene patch.
- Firestore migration.
- Worker/app deploy.
- Production commands.
- Broad Firestore rules hardening.
- Commit, push, merge, or branch operations.

## Next Safe Step

Inspect one package at a time. The recommended first package is AI Chat because it has the strongest test coverage and the highest immediate product value. POS should remain separate because it touches backend/cloud and admin surfaces.
