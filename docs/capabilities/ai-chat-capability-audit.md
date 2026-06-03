# AI Chat Capability Audit

This is the source-of-truth capability audit for the AI Chat feature. It separates product claims from verified behavior.

## Counts

| Metric | Count |
|---|---:|
| Total capabilities | 102 |
| Verified | 102 |
| Partial | 0 |
| Unverified | 0 |
| Deferred | 0 |
| Allowed tools | 16 |

## Status Rules

| Status | Meaning |
|---|---|
| `verified` | Covered by a direct unit, flow, or E2E reference. |
| `partial` | Implemented or represented, but coverage is indirect or UX quality still needs monitoring. |
| `unverified` | Claimed but not backed by current evidence. |
| `deferred` | Foundation exists, but production behavior is intentionally not enabled. |

## Allowed Tool Contract

| Tool | Status | Evidence |
|---|---|---|
| `search_products` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` |
| `update_preferences_and_recommend` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_capabilities_contract_test.dart` |
| `answer_product_question` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` |
| `ask_product_clarification` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` |
| `cheapest_catalog` | verified | `mobile_app/test/features/ai_chat/presentation/manager/catalog_query_service_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` |
| `most_expensive_catalog` | verified | `mobile_app/test/features/ai_chat/presentation/manager/catalog_query_service_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` |
| `similar_cheaper` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |
| `cheaper_followup` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |
| `show_lowest_available_after_budget_no_match` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |
| `reject_visible_products` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |
| `resolve_perfume_reference` | verified | `mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` |
| `select_perfume_reference_option` | verified | `mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/perfume_knowledge_20_scenarios_test.dart` |
| `lookup_external_perfume_profile` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` |
| `recommend_similar_to_external_profile` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` |
| `similar_cheaper_to_external_profile` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` |
| `ask_clarification` | verified | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |

## Capability Matrix

| ID | Capability | Category | Implementation Area | Evidence | Coverage | Status |
|---|---|---|---|---|---|---|
| C001 | Detect Arabic AI Chat messages. | Language & conversation | `AIChatLanguageDetector` | `mobile_app/test/features/ai_chat/core/ai_chat_language_test.dart` | unit | verified |
| C002 | Detect English AI Chat messages. | Language & conversation | `AIChatLanguageDetector` | `mobile_app/test/features/ai_chat/core/ai_chat_language_test.dart` | unit | verified |
| C003 | Keep response language aligned with the latest user message. | Language & conversation | Cubit response language routing | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C004 | Handle social micro-turns such as "how are you" as text answers with no cards. | Language & conversation | Worker/local social turn routing | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C005 | Ask a clarification for vague perfume requests. | Language & conversation | Reply handler / clarification planner | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C006 | Keep conversational fixes for messy Arabic, English, and Franco-Arabic requests. | Language & conversation | `LocalIntentParser` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_conversational_fixes_test.dart` | unit | verified |
| C007 | Extract gender preferences. | Preference extraction | `LocalIntentParser` / `PreferencePatch` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_capabilities_contract_test.dart` | unit | verified |
| C008 | Extract explicit budget and max budget. | Preference extraction | `LocalIntentParser` / `SessionPreferences` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_capabilities_contract_test.dart` | unit | verified |
| C009 | Treat explicit budget numbers as stronger than vague cheaper cues. | Preference extraction | Cubit preference merge | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C010 | Extract season preferences. | Preference extraction | `LocalIntentParser` / `SessionPreferences` | `mobile_app/test/features/ai_chat/data/models/session_preferences_policy_test.dart` | unit | verified |
| C011 | Extract occasion and use-case preferences. | Preference extraction | `LocalIntentParser` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_conversational_fixes_test.dart` | unit | verified |
| C012 | Extract time-of-day hints. | Preference extraction | `SessionPreferences` | `mobile_app/test/features/ai_chat/data/models/preference_patch_test.dart` | unit | verified |
| C013 | Extract intensity preferences. | Preference extraction | `LocalIntentParser` | `mobile_app/test/features/ai_chat/presentation/manager/preference_mutation_executor_test.dart` | unit | verified |
| C014 | Extract preferred notes. | Preference extraction | `PreferencePatch` / candidate filters | `mobile_app/test/features/ai_chat/data/models/preference_patch_test.dart` | unit | verified |
| C015 | Extract excluded notes. | Preference extraction | `PreferencePatch` / guards | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C016 | Treat allergy and medical exclusions as higher-risk constraints. | Preference extraction | Answer grounding / final guard | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard_test.dart` | unit | verified |
| C017 | Preserve preference mutation history for modifier/revert flows. | Preference extraction | `PreferenceMutationHistory` | `mobile_app/test/features/ai_chat/presentation/manager/preference_mutation_history_test.dart` | unit | verified |
| C018 | Recommend only catalog-backed products. | Catalog recommendations | Final guard / renderer | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C019 | Hide inactive products from AI recommendations. | Catalog recommendations | Catalog repo / final guard | `mobile_app/test/features/ai_chat/data/repos/ai_chat_repo_test.dart` | unit | verified |
| C020 | Hide out-of-stock products from normal recommendations. | Catalog recommendations | Final guard | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C021 | Rank candidates with catalog facet overlap. | Catalog recommendations | `CatalogSearchEngine` | `mobile_app/test/features/ai_chat/presentation/manager/catalog_search_engine_test.dart` | unit | verified |
| C022 | Apply suitability scoring to practical contexts. | Catalog recommendations | `SuitabilityPolicyEngine` / local filters | `mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart` | unit | verified |
| C023 | Generate user-facing match reasons without internal codes. | Catalog recommendations | Final guard reason builder | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C024 | Render recommendation cards only after guard validation. | Guards & safety | `FinalRecommendationGuard` / Cubit worker flow | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | flow | verified |
| C025 | Drop missing catalog IDs from worker replies. | Guards & safety | `FinalRecommendationGuard` | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C026 | Deduplicate repeated worker product IDs. | Guards & safety | `FinalRecommendationGuard` | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C027 | Block hard over-budget worker IDs. | Guards & safety | `FinalRecommendationGuard` | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C028 | Block excluded-note products before rendering. | Guards & safety | `FinalRecommendationGuard` | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C029 | Block unsupported price or note claims in answers. | Guards & safety | `AIChatAnswerGroundingGuard` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard_test.dart` | unit | verified |
| C030 | Block system prompt or internal schema leakage. | Guards & safety | `AIChatAnswerGroundingGuard` | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard_test.dart` | unit | verified |
| C031 | Reject malformed worker commands safely. | Guards & safety | Worker v2 pipeline | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | flow | verified |
| C032 | Reject unknown tool calls safely. | Guards & safety | Reply validator | `mobile_app/test/features/ai_chat/data/models/ai_chat_reply_validator_test.dart` | unit | verified |
| C033 | Ask for missing foundational slots when needed. | Clarification | Session policy / Cubit fallback | `mobile_app/test/features/ai_chat/data/models/session_preferences_policy_test.dart` | unit | verified |
| C034 | Ask clean clarification for ambiguous catalog product references. | Clarification | Availability flow / resolver | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C035 | Resolve clarification by ordinal number. | Clarification | Recommendation selection resolver | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver_test.dart` | unit | verified |
| C036 | Resolve clarification by Arabic ordinal. | Clarification | Recommendation selection resolver | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver_test.dart` | unit | verified |
| C037 | Resolve clarification by exact or partial product name when allowed. | Clarification | Selection resolver / perfume resolver | `mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart` | unit | verified |
| C038 | Keep ambiguous external references as numbered options. | Clarification | Availability message builder | `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` | e2e | verified |
| C039 | Answer exact catalog availability from catalog data. | Availability | Availability flow | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C040 | Include catalog price in availability answer. | Availability | Availability message builder | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C041 | Render a purchase card for available catalog product availability. | Availability | Reply handler / availability flow | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C042 | Explain out-of-stock availability without treating it as normal recommendation. | Availability | Availability flow | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C043 | Do not use external profile as availability proof. | Availability | Perfume knowledge availability flow | `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` | e2e | verified |
| C044 | Answer product suitability questions locally when product is clear. | Product context answers | Context answer builder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C045 | Answer product price/details follow-ups from focused product context. | Product context answers | Recommendation memory answer builder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder_test.dart` | unit | verified |
| C046 | Answer visible-card ordinal questions. | Product context answers | Recommendation memory answer builder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C047 | Compare visible products by price and intensity. | Visible product questions | Product comparison / memory builder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C048 | Answer cheapest visible product in English with no new cards. | Visible product questions | Visible products answer path | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C049 | Answer cheapest visible product in Arabic with no new cards. | Visible product questions | Visible products answer path | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C050 | Choose the best visible product for university context. | Visible product questions | Visible products context scorer | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C051 | Answer cheapest catalog query. | Direct catalog queries | `CatalogQueryService` | `mobile_app/test/features/ai_chat/presentation/manager/catalog_query_service_test.dart` | unit | verified |
| C052 | Answer most expensive catalog query. | Direct catalog queries | `CatalogQueryService` | `mobile_app/test/features/ai_chat/presentation/manager/catalog_query_service_test.dart` | unit | verified |
| C053 | Apply message filters to direct catalog queries. | Direct catalog queries | `CatalogQueryService` | `mobile_app/test/features/ai_chat/presentation/manager/catalog_query_service_test.dart` | unit | verified |
| C054 | Ignore stale session budget for most-expensive catalog query. | Direct catalog queries | Cubit direct catalog path | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C055 | Return no-match when strict budget has no product. | Budget handling | No-match builder / resolver | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C056 | Store budget no-match for later recovery. | Budget handling | Recommendation memory | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C057 | Show lowest available after explicit acceptance. | Budget handling | Tool executor | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C058 | Disclose that budget-floor result is above original budget. | Budget handling | Tool result renderer | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C059 | Exclude visible products after rejection. | Rejection memory | Deterministic commerce router | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C060 | Ask for a direction change if rejection recovery has no results. | Rejection memory | Tool executor | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` | unit | verified |
| C061 | Find cheaper alternatives after visible recommendation context. | Cheaper/similar follow-ups | `cheaper_followup` tool | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C062 | Find similar cheaper alternatives after focused product. | Cheaper/similar follow-ups | `similar_cheaper` tool | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C063 | Exclude equal-price products from cheaper pivots. | Cheaper/similar follow-ups | Cubit reference cheaper flow | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C064 | Use scent proximity before broad price sorting for similar-cheaper. | Cheaper/similar follow-ups | `ReferenceProductSimilarityRanker` | `mobile_app/test/features/ai_chat/presentation/manager/reference_product_similarity_ranker_test.dart` | unit | verified |
| C065 | Parse structured tool calls before free-form worker replies. | Semantic tools | Reply validator | `mobile_app/test/features/ai_chat/data/models/ai_chat_reply_validator_test.dart` | unit | verified |
| C066 | Execute worker tool calls app-side before rendering. | Semantic tools | Worker v2 pipeline | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | flow | verified |
| C067 | Keep allowed tools in compact context. | Semantic tools | Compact context model | `mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart` | unit | verified |
| C068 | Use `update_preferences_and_recommend` to patch preferences and recommend. | Semantic tools | Tool executor | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` | unit | verified |
| C069 | Serialize recent messages with payload limits. | Compact context | Compact context model | `mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart` | unit | verified |
| C070 | Redact sensitive text from compact context. | Compact context | Compact context model | `mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart` | unit | verified |
| C071 | Include visible products, focused product, rejected IDs, and last no-match in context. | Compact context | Compact context model | `mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart` | unit | verified |
| C072 | Include external profile and pending perfume clarification in context. | Compact context | Compact context model | `mobile_app/test/features/ai_chat/data/models/ai_chat_compact_conversation_context_test.dart` | unit | verified |
| C073 | Resolve exact catalog perfume references. | Perfume reference resolver | `PerfumeReferenceResolver` | `mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart` | unit | verified |
| C074 | Ask clarification for brand-only or series ambiguity. | Perfume reference resolver | `PerfumeReferenceResolver` | `mobile_app/test/features/ai_chat/presentation/manager/perfume_reference_resolver_test.dart` | unit | verified |
| C075 | Resolve external perfume references without guessing low-confidence names. | Perfume reference resolver | Perfume resolver / knowledge flow | `mobile_app/test/features/ai_chat/presentation/manager/perfume_knowledge_20_scenarios_test.dart` | flow | verified |
| C076 | Store external profile as scent anchor only. | External profile recommendations | Tool executor / compact context | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` | unit | verified |
| C077 | Recommend catalog-only alternatives to external profile. | External profile recommendations | External profile tool executor | `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` | e2e | verified |
| C078 | Use verified external price reference for external similar-cheaper. | External profile recommendations | External profile tool executor | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` | unit | verified |
| C079 | Avoid cheaper claim when external price reference is not verified. | External profile recommendations | External profile tool executor | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart` | unit | verified |
| C080 | Answer payment methods from trusted config only. | Business info | Business info responder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C081 | Answer contact/business info from trusted config only. | Business info | Business info responder | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C082 | Keep business-info answers text-only. | Business info | Reply handler | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C083 | Respect `shouldRenderCards` for answer/ask/recommend routing. | UI rendering control | Reply handler / tool renderer | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | flow | verified |
| C084 | Render no-match as text rather than error. | UI rendering control | Reply handler | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C085 | Preserve worker metadata for rendered replies. | Observability/testing | Worker v2 pipeline | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_worker_v2_pipeline_test.dart` | flow | verified |
| C086 | Emit structured decision and final product traces. | Observability/testing | Cubit trace callbacks | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C087 | Provide semantic assertion helper for E2E result review. | Observability/testing | E2E assertion helper | `mobile_app/test/features/ai_chat/ai_chat_semantic_assertion_helper_test.dart` | unit | verified |
| C088 | Generate richer sales-style match reasons from catalog facts. | Catalog recommendations | Final guard / reason builder | `mobile_app/test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart` | unit | verified |
| C089 | Handle worker timeout with safe local fallback. | Guards & safety | Cubit worker flow | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | flow | verified |
| C090 | Handle Egyptian "حلوة" ambiguity before treating it as sweet. | Clarification | Tool clarification / worker flow | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C091 | Continue "جميلة ولطيفة" as pleasant/clean direction, not sweet note. | Clarification | Worker tool clarification | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | e2e | verified |
| C092 | Ground Arabic external availability answers without external cards. | External profile recommendations | Availability knowledge flow | `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` | e2e | verified |
| C093 | Recover from external lookup/source failure safely. | External profile recommendations | Perfume knowledge scenarios | `mobile_app/test/features/ai_chat/presentation/manager/perfume_knowledge_20_scenarios_test.dart` | flow | verified |
| C094 | Social micro-turns return conversational answers with no product cards. | Language & conversation | Worker generated text / Cubit flow | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | e2e | verified |
| C095 | Worker timeout fallback copy stays safe and avoids unsafe random cards. | Guards & safety | Worker fallback | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart`; `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` | flow | verified |
| C096 | Live external lookup success/failure keeps external profiles as scent anchors only. | External profile recommendations | Repo / worker lookup | `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart`; `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` | unit | verified |
| C097 | Staff taste data is read and scored for reviewed/trusted complete products. | Staff taste | Staff taste scorer | `mobile_app/test/features/ai_chat/presentation/manager/staff_taste_scorer_test.dart` | unit | verified |
| C098 | Draft, partial, review-needed, and generated staff fixtures stay neutral. | Staff taste | Staff taste shadow validation | `mobile_app/test/features/ai_chat/presentation/manager/staff_taste_shadow_validation_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart` | unit | verified |
| C099 | Render-intent copy covers rejection, cheaper, similar, budget-floor, external, and no-match paths. | UI rendering control | Copy resolver / E2E logs | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart` | e2e | verified |
| C100 | Staff taste ranking is active behind guarded config with conservative weight. | Staff taste | Suitability policy engine | `mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart` | unit | verified |
| C101 | Generated staff taste seed data is blocked from real ranking. | Staff taste | Generated-data guard | `mobile_app/test/features/ai_chat/presentation/manager/staff_taste_scorer_test.dart`; `mobile_app/test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart` | unit | verified |
| C102 | Feedback analytics dashboard summarizes AI feedback and analysis safely. | Observability/testing | Admin AI Insights dashboard | `admin_dashboard/test/features/admin/data/services/admin_ai_insights_service_test.dart` | unit | verified |
