# AI Chat 100 Capability Scenarios v2 Map

This document maps the new v2 scenario suite to the audited AI Chat capabilities.

For the expanded 300-scenario coverage plan, see:

```text
docs/capabilities/ai-chat-300-scenario-map.md
```

Source test suite:

```text
mobile_app/integration_test/ai_chat_100_capability_v2_scenarios_test.dart
```

The suite is intentionally separate from the older ultra/pressure scenario suites. It is a new capability coverage layer, not a replacement.

## Coverage Rules

- Scenario count: `100`.
- Audited capability coverage: `C001` through `C102`.
- Every scenario has at least one capability ID.
- `C001-C100` are covered one-to-one by `V2-*` scenarios in order.
- `C101` is additionally covered by `V2-OPS-005`.
- `C102` is additionally covered by `V2-OPS-006`.
- Runtime backend default is mock/local; real backend is optional only.

## Scenario Map

| Scenario | Category | Capability IDs | Primary intent |
|---|---|---|---|
| V2-LANG-001 | language | C001 | Arabic greeting then Arabic perfume request |
| V2-LANG-002 | language | C002 | English social turn then perfume request |
| V2-LANG-003 | language | C003 | Arabic to English language switch |
| V2-LANG-004 | language | C004 | English to Arabic language switch |
| V2-LANG-005 | language | C005 | Franco Arabic university fresh request |
| V2-LANG-006 | language | C006 | Messy Arabic typo request |
| V2-LANG-007 | language | C007 | Very vague Arabic asks useful clarification |
| V2-LANG-008 | language | C008 | Very vague English asks useful clarification |
| V2-LANG-009 | language | C009 | Egyptian sweet ambiguity asks meaning |
| V2-LANG-010 | language | C010 | Pleasant and gentle does not become sweet note |
| V2-PREF-001 | preference | C011 | Men summer light |
| V2-PREF-002 | preference | C012 | Women evening strong |
| V2-PREF-003 | preference | C013 | Unisex gift safe direction |
| V2-PREF-004 | preference | C014 | Budget exact number |
| V2-PREF-005 | preference | C015 | Strict budget phrase |
| V2-PREF-006 | preference | C016 | Budget number beats vague cheaper |
| V2-PREF-007 | preference | C017 | Office use case |
| V2-PREF-008 | preference | C018 | University use case |
| V2-PREF-009 | preference | C019 | Wedding formal use case |
| V2-PREF-010 | preference | C020 | Date night use case |
| V2-PREF-011 | preference | C021 | Preferred notes |
| V2-PREF-012 | preference | C022 | Excluded notes |
| V2-PREF-013 | preference | C023 | Sensitive nose medical exclusion |
| V2-PREF-014 | preference | C024 | Modify and revert preference chain |
| V2-REC-001 | recommendation | C025 | Fresh daily men recommendation |
| V2-REC-002 | recommendation | C026 | Elegant women formal recommendation |
| V2-REC-003 | recommendation | C027 | Soft office recommendation |
| V2-REC-004 | recommendation | C028 | Loud night recommendation |
| V2-REC-005 | recommendation | C029 | Gift safe recommendation |
| V2-REC-006 | recommendation | C030 | Summer light recommendation |
| V2-REC-007 | recommendation | C031 | Winter night rich recommendation |
| V2-REC-008 | recommendation | C032 | No inactive or out-of-stock normal cards |
| V2-REC-009 | recommendation | C033 | Deduplicate product cards |
| V2-REC-010 | recommendation | C034 | Human readable match reasons |
| V2-REC-011 | recommendation | C035 | Generated staff data remains neutral |
| V2-REC-012 | recommendation | C036 | Trusted staff data can contribute when enabled |
| V2-SAFE-001 | safety | C037 | Prompt injection ignore rules |
| V2-SAFE-002 | safety | C038 | Invent unavailable perfume request |
| V2-SAFE-003 | safety | C039 | Ask for system prompt |
| V2-SAFE-004 | safety | C040 | Over-budget IDs blocked |
| V2-SAFE-005 | safety | C041 | Excluded note blocked |
| V2-SAFE-006 | safety | C042 | Allergy constraint respected |
| V2-SAFE-007 | safety | C043 | External perfume never renders as card |
| V2-SAFE-008 | safety | C044 | Price claims grounded |
| V2-SAFE-009 | safety | C045 | Stock claims grounded |
| V2-SAFE-010 | safety | C046 | Malformed worker response fallback |
| V2-AVL-001 | availability | C047 | Exact availability with purchase card |
| V2-AVL-002 | availability | C048 | Out of stock safe status |
| V2-AVL-003 | availability | C049 | Missing catalog product safe answer |
| V2-AVL-004 | availability | C050 | Ambiguous product reference numbered options |
| V2-AVL-005 | availability | C051 | Clarification selection by number |
| V2-AVL-006 | availability | C052 | Clarification selection by partial name |
| V2-AVL-007 | availability | C053 | Brand-only query asks focused clarification |
| V2-AVL-008 | availability | C054 | Availability typo tolerated |
| V2-AVL-009 | availability | C055 | New explicit product overrides old context |
| V2-AVL-010 | availability | C056 | Show it keeps correct availability product |
| V2-VIS-001 | visible_products | C057 | Visible cheapest English |
| V2-VIS-002 | visible_products | C058 | Visible cheapest Arabic |
| V2-VIS-003 | visible_products | C059 | Most expensive visible card |
| V2-VIS-004 | visible_products | C060 | Tell me more about second one |
| V2-VIS-005 | visible_products | C061 | Compare first and third |
| V2-VIS-006 | visible_products | C062 | Better for university |
| V2-VIS-007 | visible_products | C063 | Which one is softer |
| V2-VIS-008 | visible_products | C064 | Which one is stronger |
| V2-VIS-009 | visible_products | C065 | Why this recommendation |
| V2-VIS-010 | visible_products | C066 | Subjective better remains semantic |
| V2-BUD-001 | budget_followup | C067 | Cheaper after recommendation |
| V2-BUD-002 | budget_followup | C068 | Arabic cheaper after cards |
| V2-BUD-003 | budget_followup | C069 | Similar but cheaper focused product |
| V2-BUD-004 | budget_followup | C070 | Similar cheaper after availability product |
| V2-BUD-005 | budget_followup | C071 | Reject visible products |
| V2-BUD-006 | budget_followup | C072 | Dislike sweet mutates preference |
| V2-BUD-007 | budget_followup | C073 | Budget no-match explains safely |
| V2-BUD-008 | budget_followup | C074 | Budget floor acceptance disclosure |
| V2-BUD-009 | budget_followup | C075 | Impossible budget no hallucination |
| V2-BUD-010 | budget_followup | C076 | Equal price excluded from cheaper flow |
| V2-BUD-011 | budget_followup | C077 | Stale impossible budget ignored without new budget |
| V2-BUD-012 | budget_followup | C078 | Relative cheaper similar is not gate local-safe |
| V2-EXT-001 | external | C079 | Dior Sauvage alternatives |
| V2-EXT-002 | external | C080 | Dior line ambiguity handled |
| V2-EXT-003 | external | C081 | Select external reference option |
| V2-EXT-004 | external | C082 | External profile scent anchor only |
| V2-EXT-005 | external | C083 | External lookup failure safe clarification |
| V2-EXT-006 | external | C084 | Similar cheaper to external profile |
| V2-EXT-007 | external | C085 | External no stock or price claim |
| V2-EXT-008 | external | C086 | Low confidence external asks scent style |
| V2-EXT-009 | external | C087 | Arabic famous perfume request |
| V2-EXT-010 | external | C088 | External cheaper than it uses last profile |
| V2-BIZ-001 | business | C089 | Payment methods from config |
| V2-BIZ-002 | business | C090 | Cash on delivery |
| V2-BIZ-003 | business | C091 | Contact info no invented phone |
| V2-BIZ-004 | business | C092 | Discount request grounded |
| V2-BIZ-005 | business | C093 | Cart intent after selected recommendation |
| V2-BIZ-006 | business | C094 | Purchase CTA card only when useful |
| V2-OPS-001 | ops | C095 | Session memory tracks visible products |
| V2-OPS-002 | ops | C096 | Strong pivot prevents stale visible hijack |
| V2-OPS-003 | ops | C097 | Pending clarification resolves then clears |
| V2-OPS-004 | ops | C098 | Analytics event redacts raw identifiers |
| V2-OPS-005 | ops | C099, C101 | Gate flag off keeps behavior |
| V2-OPS-006 | ops | C100, C102 | Gate flag on strict deterministic only |

## Execution Notes

Run the metadata guard first. This is the default mode:

```powershell
cd mobile_app
flutter test integration_test\ai_chat_100_capability_v2_scenarios_test.dart
```

Run Phase 1 deterministic runtime groups explicitly:

```powershell
flutter test integration_test\ai_chat_100_capability_v2_scenarios_test.dart `
  --dart-define=AI_CHAT_100_V2_GROUP=business `
  --dart-define=AI_CHAT_100_V2_RUNTIME=true
```

Optional gate activation comparison:

```powershell
flutter test integration_test\ai_chat_100_capability_v2_scenarios_test.dart `
  --dart-define=AI_CHAT_100_V2_GROUP=business `
  --dart-define=AI_CHAT_100_V2_RUNTIME=true `
  --dart-define=AI_CHAT_DETERMINISTIC_GATE_V1=true
```

Runtime Phase 1 intentionally supports only deterministic slices first:

- `business`
- exact availability smoke cases
- selected visible-product analytical cases

The runtime result summary is published through `IntegrationTestWidgetsFlutterBinding.reportData`; it is not written from the device test process to the host filesystem.
