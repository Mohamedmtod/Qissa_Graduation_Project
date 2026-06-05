# AI Chat Branch Inventory Audit

Last updated: 2026-06-04

This is an inventory-only report for AI Chat decision branches. It is not cleanup approval.

No `DELETE_CANDIDATE` is approved for deletion by this report. Any deletion requires a separate PR, targeted tests, and staging `chatDebugId` evidence when applicable.

## Executive Summary

The AI Chat route stack currently has strong safety ownership:

- `AIChatDeterministicGate` handles deterministic proof routes.
- `AIChatRetargetProofGate` protects slot retargets from social/short/ambiguous overreach.
- `FinalRecommendationGuard` and renderer paths enforce catalog-safe cards.
- External perfume references are treated as scent anchors, not sale cards.
- Debug traces expose `route`, `source`, `action`, `renderIntent`, `fallbackUsed`, `retargetAllowed`, `retargetProofSource`, `retargetBlockedReason`, `finalProductIds`, and guard/failure reasons.

Primary cleanup guidance:

- Keep core safety, catalog, availability, external-profile, and final guard branches.
- Do not delete worker fallback branches before staging evidence.
- Retarget branches are now guarded; keep them until 10-30 staging chats confirm no unexpected branch usage.
- Future cleanup should be small-batch: 2-5 branches per PR.

## Classification Legend

| Classification | Meaning |
|---|---|
| KEEP | Required branch with clear active purpose. |
| KEEP_GUARDED | Legacy/sensitive branch protected by a gate; keep for now. |
| MERGE_CANDIDATE | Duplicates another branch and may be unified later. |
| DELETE_CANDIDATE | Looks unused/dead, but deletion is not approved here. |
| NEEDS_TEST | Important branch with insufficient targeted coverage. |
| NEEDS_STAGING_EVIDENCE | Needs real `chatDebugId` evidence before cleanup. |
| DO_NOT_TOUCH | Core safety/catalog/availability guard. |

`cleanupBatch` values:

- `none`
- `PR22B-safe-mechanical`
- `PR22C-retarget-merge`
- `PR22D-fallback-cleanup`
- `needs-staging`

## Decision Ownership Map

| Owner | Responsibility | Main debug signals |
|---|---|---|
| Deterministic gate | Exact catalog availability, direct catalog query, visible product facts, pending clarification selection, safe ambiguity clarification | `decisionOwner=deterministic_gate_v1`, `availabilityRoute`, `finalGuardDecision` |
| Local interceptors | Clear safety/dialogue blockers such as fantasy notes, contradictions, persona-only, strict gibberish | `source=local_interceptor`, `clarificationType`, `issueCode` |
| Retarget proof gate | Allows gender/budget/notes retarget only with perfume intent proof | `retargetAllowed`, `retargetProofSource`, `retargetBlockedReason` |
| LLM/semantic worker | Natural language preference, vibe, note, subjective, and external-reference understanding | `source=ai_worker`, `semanticIntent`, `toolName`, `toolStatus` |
| Dart guards/renderers | Product IDs, catalog cards, budget floor, external card ban, final copy grounding | `finalGuardDecision`, `guardBlockedCount`, `finalProductIds`, `renderIntent` |

## Retarget Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-RETARGET-001 | `ai_chat_cubit_worker_flow.dart` / `_handleWorkerFailureFallback` | Worker unavailable, not enough local criteria, next missing slot exists | `source=local_fallback`, `action=ask`, `renderIntent=no_cards` | Recover from worker failure by asking a useful missing slot | `recommend me a perfume` with worker outage | `ai_chat_cubit_conversational_policy_test`, legacy 976 | `retargetAllowed`, `retargetProofSource`, `retargetBlockedReason`, `fallbackUsed` | Medium | KEEP_GUARDED | needs-staging | Keep. Protected by `AIChatRetargetProofGate`; do not delete before staging evidence. |
| B-RETARGET-002 | `ai_chat_cubit_worker_flow.dart` / `_renderNonToolReply` | Worker ask targets filled slot or generic preference ask | `source=*ask_recovery`, `source=*filled_slot_recovery`, `source=*targeted_ask` | Prevent redundant asks and recover to recommendations where possible | Worker asks gender after gender already known | `ai_chat_social_gender_regression_test`, `ai_chat_cubit_conversational_policy_test` | `source`, `finalGuardDecision`, `retarget*` fields | Medium | KEEP_GUARDED | needs-staging | Keep. It is a safety/UX recovery branch, but retarget parts should remain guarded. |
| B-RETARGET-003 | `ai_chat_cubit.dart` / handled-result slot retarget | Tool/handled result needs next useful missing slot | `source` from handled result, `action=ask` | Continue valid recommendation clarification after a proven perfume request | `رشحلي عطر` then missing budget/gender | Targeted cubit tests, legacy 976 | `retargetAllowed`, `retargetProofSource` | Medium | KEEP_GUARDED | needs-staging | Keep until staging confirms no over-asking. |
| B-RETARGET-004 | `ai_chat_retarget_proof_gate.dart` / `evaluate` | Short/social/ambiguous turn has no perfume proof | `source=local_dialogue_no_perfume_intent`, `action=answer` | Block legacy slot retarget overreach | `hello -> yes`, `how are you -> why`, `تمام` | `ai_chat_cubit_conversational_policy_test` | `retargetBlockedReason=retarget_blocked_no_perfume_intent_proof` | Low | KEEP | none | Keep. This is the PR21 architecture safety gate. |

Answer to audit question: current gender/budget/notes retarget branches observed in worker fallback and worker ask rendering are guarded by `AIChatRetargetProofGate` or are restricted to proven recommendation/product context. Keep monitoring staging `chatDebugId` for any unguarded `ask_retarget` source.

## Local Interceptor Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-LOCAL-001 | `ai_chat_cubit_turn_flow.dart` / `_handleFantasyNoteInterception` | Fantasy/non-realistic scent note, excluding greeting and availability clarification | `source=local_interceptor`, `action=ask` | Prevent impossible/fantasy requests from becoming fake recommendations | `shawarma watermelon perfume` | Conversational policy tests, legacy 976 | `clarificationType=fantasy_note_like`, `issueCode` | Low | KEEP | none | Keep. Deterministic safety branch. |
| B-LOCAL-002 | `ai_chat_cubit_turn_flow.dart` / `_handleEarlyInterception` | Contradiction, strict gibberish, unsafe local inputs | `source=local_interceptor`, `action=ask` | Ask focused clarification instead of routing nonsense or contradictory requests | `%%%%%%%`, impossible contradictions | Conversational policy tests | `clarificationType`, `issueCode`, `reasonCode` | Low | KEEP | none | Keep. It is deterministic and bounded after PR19. |
| B-LOCAL-003 | `ai_chat_cubit_turn_flow.dart` / `_handleEarlyInterception` | Persona-only preference statement without recommendation request | `source=persona_only_interceptor`, `action=ask` | Store partial preferences and ask one useful next question | `I am a man` | Conversational policy tests | `source=persona_only_interceptor`, `clarificationType=persona_only_local_ask` | Medium | NEEDS_STAGING_EVIDENCE | needs-staging | Keep until staging shows whether persona-only turns feel too pushy. |
| B-LOCAL-004 | `ai_chat_cubit.dart` / `_tryHandleSocialMicroTurn` | Clear social micro-turn | `source=local_social_micro_turn`, `action=answer` | Fast social answer without worker/retarget | `how are you`, `كيف حالك`, `ازيك عامل اي` | Android E2E, conversational policy tests | `source=local_social_micro_turn`, `workerUsed=false` | Low | KEEP | none | Keep. Fixes Arabic social latency/gender ask regressions. |

Answer to audit question: local branches mostly make deterministic safety/dialogue decisions. Persona-only interception is the main branch needing staging evidence because it may feel like over-clarification in real chat.

## Deterministic Gate Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-GATE-001 | `ai_chat_cubit.dart` / `_tryActivateDeterministicGate` | `direct_catalog_query` | Local answer/recommend route | Answer direct catalog price/ranking facts | `أغلى عطر عندك`, `cheapest perfume` | Turn decision tests, legacy 976 | `decisionOwner=deterministic_gate_v1`, `availabilityRoute=direct_catalog_query` | Low | KEEP | none | Keep. Deterministic catalog fact route. |
| B-GATE-002 | `ai_chat_cubit.dart` / `_tryActivateDeterministicGate` | `exact_catalog_availability` | `route=availability`, catalog card policy | Answer exact availability from catalog | `Do you have Light Blue?` | Android E2E, external E2E, legacy 976 | `source=local_direct_availability_answer_only`, `finalProductIds` | Low | DO_NOT_TOUCH | none | Keep. Core catalog truth branch. |
| B-GATE-003 | `ai_chat_cubit.dart` / `_tryActivateDeterministicGate` | `deterministic_visible_product_question` | `answer_only` | Answer visible product price/position facts without new cards | `which is cheapest among them?` | E2E smoke, legacy 976 | `renderIntent=answer_only`, visible product context | Low | KEEP | none | Keep. Prevents unnecessary recommendations. |
| B-GATE-004 | `ai_chat_cubit.dart` / `_tryHandleDeterministicGateClarification` | `ambiguous_egyptian_sweet` | `source=deterministic_gate_ambiguous_egyptian_sweet`, `action=ask` | Ask sweet-vs-beautiful before gender | `رشحلي ريحة حلوة` | Android E2E, social gender regression | `clarificationType=ambiguous_egyptian_sweet` | Low | KEEP | none | Keep. Important Arabic UX branch. |
| B-GATE-005 | `ai_chat_cubit.dart` / `_tryActivateDeterministicGate` | `pending_clarification_selection` | selection resolver | Resolve numeric/name selection from pending clarification | `1`, `2`, `الثاني` | External E2E, selection tests | `availabilityRoute=pending_clarification_selection` | Low | KEEP | none | Keep. Required for external ambiguity and product selections. |

## Availability Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-AVAIL-001 | `availability_route_resolver.dart` / `resolve` | Explicit availability product query with product anchor | `AvailabilityRoute.direct` | Route exact availability safely | `Do you have Light Blue?`, `عندك لايت بلو؟` | Availability resolver tests, Android E2E | `availabilityRoute=direct`, `reasonCode=availability_explicit_product` | Low | DO_NOT_TOUCH | none | Keep. Core exact availability path. |
| B-AVAIL-002 | `availability_route_resolver.dart` / `resolve` | Existing availability context follow-up | `AvailabilityRoute.followUp` | Continue availability substitute/similar context | `what about cheaper?` after availability | E2E/legacy | `availability_contextual_follow_up` | Medium | KEEP | none | Keep. Needs staging watch for context switches. |
| B-AVAIL-003 | `availability_route_resolver.dart` / `resolve` | Similar-cheaper pivot after found availability | `AvailabilityRoute.similarCheaperPivot` | Pivot from available product to similar/cheaper alternatives | `similar but cheaper` | Android E2E | `availability_matched_similar_cheaper_pivot` | Medium | KEEP | none | Keep. Commerce follow-up route. |
| B-AVAIL-004 | `availability_route_resolver.dart` / `_shouldSkipAvailabilityRouting` | Recommendation/vibe/note signal under Router V2 | `AvailabilityRoute.none` | Prevent natural preference turns from being hijacked by availability | `is there with mango?`, `something fresh` | PR15 tests, legacy 976 | `availability_route_skipped_recommendation_signal` | Medium | KEEP | none | Keep. Important route ownership guard. |

Answer to audit question: availability branches generally require product anchor/context under Router V2. Generic natural-language preference should skip availability.

## Worker Ask / Fallback Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-WORKER-001 | `ai_chat_cubit_worker_flow.dart` / `_handleWorkerFailureFallback` | Worker returns no reply / unavailable | `source=local_fallback`, may answer/recommend/ask/noMatch | Preserve UX when worker/model fails | Real worker empty reply | Android E2E watch item, legacy 976 | `failureReason=worker_empty_reply`, `fallbackUsed=true` | High | NEEDS_STAGING_EVIDENCE | needs-staging | Keep. Do not cleanup before staging worker-quality evidence. |
| B-WORKER-002 | `ai_chat_worker_reply_service.dart` / worker reply normalization | Worker generic ask / missing slot | `source=ask_retarget` | Normalize generic worker asks into a local missing-slot ask | Worker asks `Tell me preferences...` | Conversational policy tests | `source=ask_retarget` | Medium | KEEP_GUARDED | PR22C-retarget-merge | Candidate to merge with Cubit retarget handling after staging. |
| B-WORKER-003 | `ai_chat_cubit_worker_flow.dart` / tool ask rendering | Tool result is ask | `route=semantic_tool`, `source=tool_ask_clarification` or tool source | Render semantic tool clarification | `which product do you mean?` | External E2E, legacy 976 | `toolName`, `toolStatus`, `clarificationType` | Medium | KEEP | none | Keep. Tool ask is explicit semantic output. |
| B-WORKER-004 | `ai_chat_cubit_worker_flow.dart` / non-tool answer grounding | Worker answer is ungrounded | `source=*_grounding_blocked`, `action=ask` | Prevent ungrounded answer facts | Worker answers product fact without visible/catalog proof | Grounding/copy tests | `issueCode=groundingDecision.reasonCode` | High | DO_NOT_TOUCH | none | Keep. Core hallucination guard. |
| B-WORKER-005 | `ai_chat_cubit_worker_flow.dart` / ask recovery | Worker ask but local candidates exist | `source=*_ask_recovery`, `action=recommend` | Avoid unnecessary asks when safe candidates exist | Worker asks despite filled practical preferences | Conversational policy tests, legacy 976 | `finalGuardDecision=ask_recovery`, `finalProductIds` | Medium | KEEP | none | Keep. Reduces over-clarification. |

Answer to audit question: fallback branches can render cards only through local candidates and final guards. `B-WORKER-001` is the main staging watch item.

## External Knowledge Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-EXT-001 | `ai_chat_cubit.dart` / external family ambiguity precheck | Single-token or family-like external reference | `external_reference_local_tool` / clarification | Ask top options instead of autopick | `Sauvage`, `Blue` | External E2E, W4.1 smoke | `modelId=external_family_ambiguity_v1`, pending clarification | Medium | KEEP | none | Keep. Prevents broad autopick. |
| B-EXT-002 | `ai_chat_tool_executor.dart` / external lookup | Lookup ambiguous | `renderIntent=externalReferenceClarification` | Present external candidates, no product cards | `Do you have Dior?` | External E2E | `traceReason=external_lookup_ambiguous`, `externalProfileId` if selected later | Medium | KEEP | none | Keep. Safe ambiguity handling. |
| B-EXT-003 | `ai_chat_cubit_worker_flow.dart` / external lookup failure fallback | Unverified external reference and worker failure | `source=external_lookup_failed_no_profile`, `action=ask` | Avoid fake profile/card when lookup fails | `Something like unknown perfume` | External E2E, copy tests | `issueCode=external_lookup_failed`, `reasonCode=external_profile_unverified` | High | DO_NOT_TOUCH | none | Keep. Core external safety branch. |
| B-EXT-004 | `ai_chat_tool_executor.dart` / similar external profile | Verified/cached external profile exists | `source=tool_recommendSimilarToExternalProfile`, `renderIntent=externalProfileSimilarResults` | Recommend catalog-only alternatives from scent anchor | `Something like Dior Sauvage` | External E2E | `externalProfileId`, `guardBlockedCount`, `finalProductIds` | High | DO_NOT_TOUCH | none | Keep. Core external feature and card-safety guard. |
| B-EXT-005 | `ai_chat_tool_executor.dart` / cheaper external profile | Last external profile used for cheaper/similar follow-up | `source=tool_similarCheaperToExternalProfile` | Catalog-only cheaper/similar alternatives | `cheaper than it` | External E2E | `externalProfileId`, `renderIntent=externalProfileCheaperResults` | High | DO_NOT_TOUCH | none | Keep. Needs monitoring for price-reference disclosure quality. |

Answer to audit question: external failure paths are designed not to render external product cards. Card rendering stays catalog-only through tool executor and final guard.

## No-Match / Budget Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-NOMATCH-001 | `ai_chat_cubit.dart` / worker-first local precheck | No candidates under strict/floor budget | `source=worker_first_local_precheck`, `route=no_match` | Honest no-match before unsafe recommendation | `men summer fresh under 600` | Android E2E, legacy 976 | `noMatchReason=budget_no_match`, `failureReason` | Medium | KEEP | none | Keep. Correct catalog truth branch. |
| B-NOMATCH-002 | `ai_chat_tool_executor.dart` / budget floor acceptance | Previous budget no-match and user accepts lowest option | `source=tool_showLowestAvailableAfterBudgetNoMatch`, `renderIntent=budgetFloorDisclosure` | Show lowest available above budget with disclosure | `ok show me it` | Android E2E | `toolName=showLowestAvailableAfterBudgetNoMatch`, `finalProductIds` | Low | KEEP | none | Keep. Good recovery branch. |
| B-NOMATCH-003 | `ai_chat_cubit_worker_flow.dart` / final guard no-match | Tool/worker candidates empty after guard | `source=*_no_match`, `route=no_match` | Avoid unsafe/fake recommendations | Strict allergy/budget/no safe candidates | Legacy 976 | `guardBlockedCount`, `failureReason`, `noMatchReason` | High | DO_NOT_TOUCH | none | Keep. Core safety branch. |
| B-NOMATCH-004 | `ai_chat_no_match_builder.dart` / note/catalog gaps | Requested note/style not confidently in catalog | no cards | Honest catalog note gap message | `with mango`, `rose`, `vanilla without oud` | Legacy 976 | `noMatchReason`, triage in audit | Medium | NEEDS_STAGING_EVIDENCE | needs-staging | Keep. Improve via catalog/note coverage, not cleanup. |

Answer to audit question: no-match with candidates is generally guarded/recovered. Current high-count no-match caveats are mostly budget/catalog-note gaps, not route dead code.

## Final Guard / Render Branches

| ID | File / Function | Condition | Route / Source / Action | Purpose | Example Inputs | Tests | Observability | Risk | Classification | cleanupBatch | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| B-GUARD-001 | `final_recommendation_guard.dart` / `guard` | Worker/tool returns product IDs/candidates | Safe products, local recovery, or no-match | Remove invalid/external/unsafe products before rendering | Worker returns fake ID | Worker/normalization tests, legacy 976 | `finalGuardDecision`, `guardBlockedCount`, `finalProductIds` | High | DO_NOT_TOUCH | none | Keep. Core product hallucination guard. |
| B-GUARD-002 | `ai_chat_response_copy_engine.dart` / copy sanitizers | Internal reason strings/generic copy appear | user-facing replacement | Hide internal policy/reason codes | `fallback from candidates`, `no_match_reason` | Copy/mojibake tests | Copy tests, not always per-turn source | Medium | KEEP | none | Keep. Copy safety, not cleanup target. |
| B-GUARD-003 | `ai_chat_cubit_worker_flow.dart` / answer grounding | Answer is not grounded in visible/catalog facts | ask/recovery answer | Prevent unsupported facts in text answers | Worker explains product not visible | Grounding tests | `source=*_grounding_blocked`, `issueCode` | High | DO_NOT_TOUCH | none | Keep. Core hallucination guard. |
| B-GUARD-004 | `ai_chat_cubit_context_followups.dart` / product context answer routes | Product/follow-up answer should not render cards | `answer_only` | Answer analytical product questions without new cards | `is Light Blue good for work?` | Android E2E, context tests | `finalGuardDecision=answer_route_cards_blocked` | Medium | KEEP | none | Keep. Prevents UI churn. |

## Cleanup Candidates

| Candidate | Reason | Required Before Cleanup |
|---|---|---|
| Retarget normalization split between worker reply service and Cubit worker flow | `ask_retarget`, generic ask recovery, and targeted ask are spread across multiple points | 10-30 staging chats, source frequency review, targeted tests for every retarget source |
| Worker fallback ask/no-match branches | Several fallback branches return ask/no-match from similar local criteria | Staging evidence for `worker_empty_reply`, confirmation no rare fallback protects real worker outage |
| Persona-only local ask | Could be useful but may feel pushy in real chat | Staging chatDebugId examples for persona-only statements |

No cleanup is approved in PR22A.

## Needs Tests / Needs Staging Evidence

| Area | Need |
|---|---|
| Persona-only interceptor | Staging examples to decide whether it should ask immediately or defer to semantic/dialogue. |
| Worker empty fallback | Real staging frequency and UX quality by `chatDebugId`. |
| External cheaper follow-up after failed exact cheaper search | Confirm whether clarification vs nearest cheaper catalog alternatives feels better. |
| Note/catalog no-match | Data coverage decision, not branch cleanup. |
| Retarget source frequency | Count `ask_retarget`, `*_targeted_ask`, and `local_dialogue_no_perfume_intent` in staging debug sessions. |

## Recommended PR22B Scope

Do not start PR22B until staging observation has at least 10-30 real/internal chats.

If staging is clean, PR22B should be small and mechanical:

1. Add targeted tests for any `NEEDS_TEST` branch still missing coverage.
2. Merge duplicated retarget helpers only if all sources remain covered.
3. Do not remove worker fallback or external safety branches.
4. Keep cleanup to 2-5 branch-level changes maximum.

