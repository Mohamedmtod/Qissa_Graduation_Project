# Current Test Status

Last updated: 2026-05-25
Purpose: current source of truth for automated test status after the defense stabilization pass.

## Final Automated Verification

All core automated checks are green:

| Area | Command | Result |
| --- | --- | --- |
| Main Flutter app static analysis | `flutter analyze` | PASS |
| Main Flutter app tests | `flutter test` | PASS, 385 tests |
| Admin dashboard static analysis | `flutter analyze` from `perfume_app_admin_dashboard` | PASS |
| Admin dashboard tests | `flutter test` from `perfume_app_admin_dashboard` | PASS, 81 tests |
| Auth worker | `npm test` from `perfume-auth-worker` | PASS, 11 tests |
| AI chat worker | `npm test` from `perfume-ai-chat-worker` | PASS, 15 tests |
| Orders worker | `npm test` from `perfume-orders-worker` | PASS, 5 tests |
| Firestore rules | `firebase emulators:exec --only firestore "npm --prefix functions run test:rules"` | PASS |
| AI budget/upsell integration smoke | `flutter test integration_test/ai_chat_budget_upsell_test.dart` | PASS, 3 tests |
| AI Chat business info live runner | `dart run tool/ai_chat_business_info_live_runner.dart --device emulator-5554 --fail-on-needs-fix` | PASS, 14/14 |
| AI Chat 20 memory live runner | `dart run tool/ai_chat_20_memory_live_runner.dart --device emulator-5554 --fail-on-needs-fix` | PASS, 20/20 |
| AI Chat 40 live runner | `dart run tool/ai_chat_40_live_runner.dart --device emulator-5554 --full` | PASS, 40/40 |
| AI Chat 100 live runner | `dart run tool/ai_chat_100_live_runner.dart --device emulator-5554 --full` | PASS, 132/132 |

## Fixes Since Older Test Summaries

- Fixed AI Chat out-of-stock availability regression.
- Fixed AI Chat compare-path context regression.
- Fixed AI Chat external-profile substitute regression.
- Fixed AI Chat memory continuation filled-slot guard regression.
- Fixed admin dashboard Mocktail named-argument stubs.
- Fixed AI budget/upsell integration test stubs for `saveAIChatDebugLog` and `requestId`.
- Aligned AI upsell integration assertions with current `conversion_upsell_*` telemetry names.
- Removed the orders worker test module-type warning by using `node --experimental-default-type=module` in its test script.
- Moved the local Firestore emulator port to `127.0.0.1:8085` to avoid port 8080 conflicts.
- Updated availability follow-up context switching behavior to require explicit switch-intent before replacing active availability context.
- Preserved `availability` message type in transcript compaction and separated telemetry emission via `availability_answer_shown`.
- Completed AI Chat PR8 post-RC targeted routing and suitability fixes:
  - product-context questions answer locally without new cards
  - ambiguous visible product references ask clarification
  - clarification replies by number/name resolve locally
  - direct Arabic catalog queries run locally before interpretation worker
  - visible recommendation reasons hide internal suitability codes

## Latest AI Chat PR8 Targeted Verification (2026-05-25)

| Area | Command | Result |
| --- | --- | --- |
| AI Chat static analysis | `dart analyze lib/features/ai_chat test/features/ai_chat` | PASS |
| AI Chat Cubit regression | `flutter test test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | PASS, 117/117 |
| Suitability policy | `flutter test test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart` | PASS, 9/9 |
| Worker v2 headless pipeline | `flutter test test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | PASS, 12/12 |
| Render contract | `flutter test test/features/ai_chat/presentation/widgets/ai_chat_render_contract_test.dart` | PASS, 2/2 |
| Catalog query service | `flutter test test/features/ai_chat/presentation/manager/catalog_query_service_test.dart` | PASS, 5/5 |
| Final recommendation guard | `flutter test test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | PASS, 16/16 |

## Latest Code-Level Documentation Alignment (2026-05-14)

- Worker/API docs now reflect `action_type` support for `answer`/`info` in addition to `ask`/`recommend`.
- Analysis transcript contract docs now include assistant `availability` message type.
- Shared telemetry taxonomy docs now include the newer availability and perfume-knowledge event families used by the current app runtime.

## Not Covered By Automated Green Status

These remain manual/live checks, not current automated failures:

- Real-device layout sanity in Arabic and English.
- Real Resend OTP email delivery.
- Live checkout/order/cancel against the final deployed worker URLs.
- Live AI latency on the defense network.
- Admin dashboard visual review with the final demo Firestore data.
- Backup recording playback.

## AI Scenario Artifacts

The AI chat scenario suites are now useful as regression evidence in addition to diagnosis:

- Business info: `14/14` passed
- Memory regression: `20/20` passed
- Realistic 40-scenario suite: `40/40` passed
- Full 100-scenario suite: `132/132` passed

The runs still include some `passed_with_caveat` outcomes, so they remain quality evidence rather than a blanket production promise. Use the manual checklist in `docs/defense-guide.md` for final demo verification.
