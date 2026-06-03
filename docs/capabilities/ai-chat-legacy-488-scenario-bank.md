# AI Chat Legacy 488 Scenario Bank

This document records how the old bilingual scenario catalog is used by the
current AI Chat validation strategy.

Source:

```text
docs/old tests/ai_chat_scenarios_bilingual.md
```

## Current Status

| Metric | Value |
|---|---:|
| Scenario pairs | 488 |
| English variants | 488 |
| Arabic variants | 488 |
| Total language-specific variants | 976 |
| English message turns | 785 |
| Arabic message turns | 785 |
| One-turn scenarios | 314 |
| Multi-turn scenarios | 174 |
| Maximum turns in one scenario | 7 |
| Unique EN fingerprints | 474 |
| Unique AR fingerprints | 474 |
| Duplicate fingerprint groups | 12 |

The current 10-turn runtime cap is enough for this legacy bank because the
longest scenario has 7 turns.

## How It Is Validated

The metadata guard is:

```powershell
cd mobile_app
flutter test test\features\ai_chat\presentation\manager\ai_chat_legacy_488_scenario_bank_test.dart
```

The guard verifies:

- the old file still parses as 488 bilingual scenario pairs.
- EN and AR variants can be split deterministically.
- generated IDs are stable:
  - `LEG-EN-001` through `LEG-EN-488`
  - `LEG-AR-001` through `LEG-AR-488`
- the old bank remains bounded under the current 10-turn runtime cap.
- duplicate message fingerprints are recorded for later dedup instead of being
  hidden.
- high-value coverage areas are present, including prompt injection,
  availability, external perfume references, Dior Sauvage, raw JSON/percent UI
  checks, and no internal prompt leakage.

## Runtime Policy

Do not run all 976 language variants against the real backend by default.

Recommended rollout:

1. Metadata guard only.
2. Mocked runtime batches by category/language.
3. Selected real-backend smoke only for high-risk paths.

Suggested future filters:

```text
AI_CHAT_LEGACY_RUNTIME=true
AI_CHAT_LEGACY_LANGUAGE=en|ar
AI_CHAT_LEGACY_GROUP=safety|availability|external|memory|budget|ui
AI_CHAT_LEGACY_SCENARIO_ID=LEG-EN-001
```

## Assertion Policy

The old expected text must not be used as exact UI copy assertions. Many legacy
expectations were written for older summary/debug output such as:

```text
Expected to contain: Men, Season: Summer, Under 1200
```

Modern assertions should be semantic:

- reply type: answer, ask, recommendation, availability, no-match.
- card policy: no cards, purchase CTA card, recommendation grid.
- catalog-only product cards.
- no fake price, stock, or availability.
- no external perfume cards.
- no raw JSON, prompt text, internal keys, or bare match percentages.
- no mojibake.
- budget, exclusion, allergy, and safety constraints respected.

## Notes

- The old catalog is useful as a scenario bank, not as a direct runtime suite.
- Duplicates are expected and tracked. They should be deduplicated or marked
  intentionally before any large runtime batch.
- The old Arabic text should be read as UTF-8. Some terminals may display it as
  mojibake even when the file content itself is valid.
