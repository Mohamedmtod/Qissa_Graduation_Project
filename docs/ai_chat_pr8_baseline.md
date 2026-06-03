# AI Chat PR8 Baseline

Date: 2026-05-24

## Targeted Flutter Baseline

- `ai_chat_cubit_test.dart`: 107/107 passed.
- `ai_chat_worker_v2_pipeline_test.dart`: 10/10 passed.
- `ai_chat_render_contract_test.dart`: 2/2 passed.
- `dart analyze lib/features/ai_chat test/features/ai_chat`: clean, no issues found.

## Worker Baseline

- Command: `npm test --prefix backend_and_cloud/workers/perfume-ai-chat-worker`
- Result: 0 passed / 1 failed before test execution.
- Failure reason: missing local worker dependency `@upstash/redis` imported by `src/index.js`.
- Classification: environment/dependency install issue, not a Flutter AI Chat regression.

## Notes

- The first attempted parallel Flutter baseline run hit Windows build asset locks under `build/unit_test_assets`. Sequential runs passed.
- This document is the original PR8 baseline and is superseded for release status by `docs/ai_chat_pr8_release_candidate.md`.
- Baseline gaps that were later reduced or closed:
  - Suitability for clear university/daily/light contexts is now handled through catalog search plus suitability scoring behind flags, with post-RC scoring adjusted to prefer ranking penalties over broad context hard-blocks.
  - Product-context questions such as `is Light Blue suitable for work?` now resolve locally as text answers without rendering new cards.
  - Direct catalog queries such as `أغلى عطر عندك` now resolve locally before interpretation-worker escalation.
- Remaining follow-up:
  - External perfume smoke confirmation for Azzaro and Sauvage-like requests should still be covered in staging UI smoke before broad rollout.
