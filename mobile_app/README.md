# QISSAH Mobile App

Flutter customer app for the QISSAH perfume commerce experience.

## Main Areas

- Catalog browsing, product details, cart, checkout, and order history
- Firebase authentication and session-aware customer flows
- Catalog-bounded AI Chat for perfume recommendations, availability, product follow-ups, and business info
- Arabic/English UI support

## AI Chat Notes

The mobile AI Chat is not an LLM-only chatbot. The app keeps final authority over catalog validation, route/action decisions, suitability scoring, final guards, and rendering.

Current PR8 behavior includes:

- product-context questions such as `is Light Blue suitable for work?` answer locally as text only
- ambiguous visible-card references ask for clarification instead of guessing
- direct catalog queries such as `أغلى عطر عندك` resolve locally before interpretation-worker escalation
- recommendation reasons are sanitized so internal suitability codes are not shown to users
- PR8 production flags remain conservative/off until staging smoke approval

## Useful Commands

```powershell
flutter pub get
dart analyze lib/features/ai_chat test/features/ai_chat
flutter test test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart
flutter test test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart
flutter test test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart
flutter test test/features/ai_chat/presentation/widgets/ai_chat_render_contract_test.dart
```

## Canonical Docs

- `../docs/current-project-status.md`
- `../docs/current-test-status.md`
- `../docs/ai_chat_pr8_release_candidate.md`
- `../docs/capabilities/ai-chat-capabilities.md`
