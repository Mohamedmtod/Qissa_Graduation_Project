# AI Chat Structure And Flow

Last updated: 2026-05-28

This document maps the current AI Chat files, their responsibilities, and the intended runtime flow. The core rule is:

```text
LLM understands language and chooses a response/tool.
Dart executes tools, validates results, applies catalog guards, and renders UI.
Catalog is the source of truth for products, price, stock, and cards.
Perfume knowledge is a scent/profile anchor only.
```

## High-Level Structure

```text
User UI
  |
  v
AIChatPage / widgets
  |
  v
AIChatCubit
  |
  +--> Turn analysis / local safety gates
  |
  +--> Worker delegation
  |      |
  |      v
  |   AI Worker /api/chat
  |      |
  |      v
  |   Structured reply or tool_call
  |
  +--> Tool executor
  |
  +--> Catalog search / scoring / guards
  |
  +--> Reply handler
  |
  v
State + UI render
```

## Runtime Flow

### 1. User Sends Message

```text
AIChatPage
  -> AIChatCubit.sendMessage(text)
  -> AIChatTurnService builds AIChatTurnContext
  -> AIChatTurnDecisionEngine classifies the turn
```

At this stage the app may detect:

```text
greeting/social
recommendation request
follow-up
availability check
direct catalog query
product context question
business info
safety/out-of-domain input
```

### 2. Local Safety And Deterministic Gates

Local code is allowed to answer only when the behavior must be deterministic or protective:

```text
business info from config
exact catalog availability
direct catalog queries: cheapest / most expensive
visible-card references: first / second / product name
product-context answers grounded in catalog data
budget no-match recovery
rejection memory
hard safety: allergies, invalid/out-of-domain, unknown products, guard blocks
```

Local code should not own natural conversation copy when the worker is available. Natural social replies and ambiguous language should go to the LLM/tool router.

### 3. Worker Delegation

```text
AIChatWorkerReplyService
  -> builds compact context when enabled
  -> calls AIChatRepo.fetchAIRecommendationWithContext(...)
  -> receives AIChatReply
  -> normalizes ask/recommend/answer/tool_call
```

The worker can return:

```text
message      -> text answer
ask          -> targeted question
recommendation -> candidate product IDs
tool_call    -> deterministic app tool to execute
no_match     -> safe no-match
```

### 4. Tool Execution

```text
AIChatToolExecutor
  -> validates tool name and arguments
  -> executes app-owned logic
  -> returns AIChatToolExecutionResult
AIChatToolResultRenderer
  -> turns tool result into answer/ask/recommend state
```

Allowed tool examples:

```text
search_products
update_preferences_and_recommend
reject_visible_products
cheaper_followup
similar_cheaper
show_lowest_available_after_budget_no_match
resolve_perfume_reference
select_perfume_reference_option
recommend_similar_to_external_profile
similar_cheaper_to_external_profile
ask_clarification
```

### 5. Recommendation Validation

```text
CatalogSearchEngine / LocalCandidateFilter
  -> produce candidate products
SuitabilityPolicyEngine / StaffTasteScorer
  -> score and explain fit
FinalRecommendationGuard
  -> final render permission
```

Cards are rendered only if:

```text
product exists in catalog
product is active/in stock
budget/allergy/excluded-note rules are respected
external profile is not being rendered as a product
FinalRecommendationGuard allows it
```

### 6. Reply Rendering

```text
AIChatReplyHandler
  -> handleAnswerReply
  -> handleAskReply
  -> handleRecommendationReply
  -> replyWithFallback / no-match
```

UI rendering is controlled by message type:

```text
answer       -> text only
ask          -> text only
availability -> text/card grounded in catalog
recommend    -> catalog cards only
noMatch      -> safe no-match text
error        -> technical fallback
```

## File Responsibility Map

### UI Layer

| File | Responsibility |
|---|---|
| `mobile_app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart` | Main chat screen, input field, list rendering, Cubit binding. |
| `mobile_app/lib/features/ai_chat/presentation/widgets/chat_message_bubble.dart` | Renders user/bot text bubbles. |
| `mobile_app/lib/features/ai_chat/presentation/widgets/recommended_product_card.dart` | Renders catalog product cards only. Must not render external perfume profiles. |

### Cubit Orchestration Layer

| File | Responsibility |
|---|---|
| `ai_chat_cubit.dart` | Primary orchestrator. Owns session state, turn flow order, worker delegation, local gates, and final dispatch. Should not contain large business algorithms. |
| `ai_chat_cubit_turn_flow.dart` | Shared turn helpers, early interceptions, modifier handling, fallback helpers. |
| `ai_chat_cubit_recommendation_flow.dart` | Recommendation rendering/recovery flow. |
| `ai_chat_cubit_worker_flow.dart` | Worker-first/tool-call handling and worker reply rendering. |
| `ai_chat_cubit_availability_flow.dart` | Catalog availability and external-profile availability-safe alternatives. |
| `ai_chat_cubit_context_followups.dart` | Visible-card/product follow-up flows and context references. |
| `ai_chat_cubit_quality_guards.dart` | Quality/safety gates for impossible, vague, unsafe, or contradictory inputs. |
| `ai_chat_state.dart` | Cubit state: messages, status, preferences, availability context, recommendation memory. |

### Turn Understanding And Routing

| File | Responsibility |
|---|---|
| `ai_chat_turn_service.dart` | Builds incoming turn context and message metadata. |
| `ai_chat_turn_decision_engine.dart` | Determines broad route: recommendation, availability, clarify, off-topic, local command. |
| `ai_chat_interpretation_service.dart` | Optional interpretation-worker result application. |
| `ai_chat_worker_reply_service.dart` | Calls chat worker and normalizes worker reply behavior. |
| `ai_chat_experiment_config.dart` | Runtime flags for compact context, tool router, worker-first, catalog search, suitability policy. |
| `ai_chat_input_interceptor.dart` | Narrow local safety interception for fantasy/gibberish/contradiction/luxury-budget mismatch. Not for normal conversation copy. |
| `ai_chat_text_normalizer.dart` | Text normalization used by parsers and matchers. |
| `local_intent_parser.dart` | Local extraction of explicit preferences and deterministic signals. |
| `local_intent_parser_keywords.dart` | Keyword sets for local parser. |
| `local_intent_parser_matchers.dart` | Matcher helpers for parser logic. |

### Worker Contract And Reply Parsing

| File | Responsibility |
|---|---|
| `data/models/ai_chat_reply.dart` | App-side structured reply model: ask, answer, recommend, toolCall. |
| `data/models/ai_chat_tool_call.dart` | Tool call names and JSON parsing. |
| `data/models/ai_chat_reply_validator.dart` | Validates worker structured response before Cubit uses it. |
| `data/models/ai_chat_structured_reply.dart` | Structured worker reply representation. |
| `data/models/ai_chat_compact_conversation_context.dart` | Compact context sent to worker: recent messages, visible products, memory, preferences. |
| `data/models/preference_patch.dart` | Safe preference patch operations. |
| `backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js` | Worker prompt, schema, response normalization, tool-call sanitization, external lookup helpers. |
| `backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js` | Worker contract tests. |

### Tool Execution Layer

| File | Responsibility |
|---|---|
| `ai_chat_tool_executor.dart` | Executes validated tool calls. Owns deterministic commerce/external-profile tool behavior. |
| `ai_chat_tool_result_renderer.dart` | Converts tool execution results to UI-safe replies. |
| `ai_chat_deterministic_commerce_router.dart` | Locally routes deterministic commerce follow-ups such as reject/cheaper/budget-floor. |
| `ai_chat_local_catalog_command_handler.dart` | Handles local catalog commands that do not need LLM. |
| `preference_mutation_executor.dart` | Applies structured preference mutations. |
| `preference_mutation_history.dart` | Tracks preference mutation history for reversibility/context. |

### Catalog Search, Scoring, And Guards

| File | Responsibility |
|---|---|
| `catalog_search_engine.dart` | Search products by preferences, notes, tags, facets. |
| `catalog_facet_index.dart` | Indexes product facets and staff facets. |
| `local_candidate_filter.dart` | Filters candidate products for local recommendation flows. |
| `suitability_policy_engine.dart` | Scores product suitability and mismatch reasons. |
| `staff_taste_scorer.dart` | Shadow/flagged staff taste score. Generated seed data must stay neutral unless reviewed/trusted. |
| `final_recommendation_guard.dart` | Last gate before cards can render. |
| `scent_profile_scorer.dart` | Compares scent profile anchors and product scent vectors. |
| `reference_product_similarity_ranker.dart` | Similarity ranking to a catalog product/reference profile. |
| `ai_chat_recommendation_resolver.dart` | Resolves recommendations and no-match conditions. |
| `ai_chat_worker_first_experiment.dart` | Worker-first recommendation resolver path. |

### Product, Context, And Memory

| File | Responsibility |
|---|---|
| `data/models/session_preferences.dart` | Source of truth for current user preferences. |
| `data/models/recommendation_memory.dart` | Visible cards, rejected products, last focused product, no-match context, external profile context. |
| `ai_chat_recommendation_memory_utils.dart` | Memory helper functions. |
| `ai_chat_recommendation_memory_answer_builder.dart` | Builds grounded text answers about visible/recent recommendations. |
| `ai_chat_recommendation_selection_resolver.dart` | Resolves user references like `first`, `2`, or partial product names. |
| `recommendation_reference_resolver.dart` | Resolves recommendation anchors. |
| `mentioned_product_resolver.dart` | Finds product mentions in messages. |
| `ai_chat_product_context_signals.dart` | Detects product-context question signals. |
| `product_followup_answer_builder.dart` | Builds catalog-grounded product follow-up answers. |
| `product_comparison_engine.dart` | Compares visible/catalog products. |

### Availability And External Perfume Knowledge

| File | Responsibility |
|---|---|
| `availability_flow_service.dart` | Availability flow coordinator. |
| `availability_route_resolver.dart` | Resolves availability route. |
| `availability_lookup_service.dart` | Catalog availability lookup. |
| `availability_substitute_engine.dart` | Finds catalog substitutes for known unavailable external perfumes. |
| `availability_reference_profile_registry.dart` | Legacy/static external reference profiles. Keep until new resolver fully replaces it. |
| `availability_followup_detector.dart` | Detects availability follow-up context. |
| `availability_intent_utils.dart` | Availability intent helpers. |
| `availability_hint_builders.dart` | Availability clarification hints. |
| `availability_message_builder.dart` | Availability-safe user copy. |
| `perfume_reference_resolver.dart` | Resolves catalog/external perfume references and ambiguity. |
| `data/models/perfume_knowledge_profile.dart` | Structured external perfume profile. |
| `data/models/external_perfume_candidate.dart` | External lookup candidate. |
| `data/models/external_perfume_lookup_result.dart` | External lookup result. |

### Repository And Persistence

| File | Responsibility |
|---|---|
| `data/repos/ai_chat_repo.dart` | Boundary to catalog, Firestore/session persistence, worker calls, perfume knowledge, business info. |
| `ai_chat_session_persistence_helper.dart` | Chat session persistence. |
| `ai_chat_session_actions.dart` | UI actions from chat messages/cards. |
| `ai_chat_session_id_store.dart` | Stores/restores last session id. |
| `ai_chat_stored_message_restorer.dart` | Restores stored messages and product cards. |
| `ai_chat_feedback_helper.dart` | Feedback events and feedback persistence. |
| `data/models/ai_chat_message.dart` | Chat message UI/domain model. |
| `data/models/ai_chat_feedback.dart` | Feedback model. |
| `data/models/restock_request_model.dart` | Restock request data. |
| `data/models/analysis_transcript_payload.dart` | Analysis/telemetry transcript payload. |

### Copy, Normalization, And Utilities

| File | Responsibility |
|---|---|
| `ai_chat_copy_resolver.dart` | Shared static copy for welcome/fallback/slot questions. Should not contain normal LLM conversation templates. |
| `ai_chat_interceptor_copy.dart` | Copy for local safety interceptors. |
| `ai_chat_no_match_builder.dart` | No-match and fallback explanation text. |
| `ai_chat_reply_handler.dart` | Converts replies into `AIChatState` messages/statuses. |
| `ai_chat_reply_normalizer.dart` | Normalizes worker ask/reply content. |
| `ai_chat_runtime_utils.dart` | Runtime helpers. |
| `ai_chat_slot_utils.dart` | Slot inference helpers. |
| `ai_chat_summary_builder.dart` | Summary/telemetry builders. |
| `ai_chat_analytics_utils.dart` | Analytics helpers. |
| `ai_chat_budget_policy.dart` | Budget policy helpers. |
| `budget_amount_parser.dart` | Budget number parsing. |
| `ai_normalization_dictionary.dart` | Canonical notes/tags and aliases. |
| `ai_normalizer.dart` | High-level normalization utilities. |
| `staff_taste_taxonomy.dart` | Staff taste tag taxonomy. |
| `ai_chat_language.dart` | Language enum and helpers. |
| `ai_chat_config.dart` | AI Chat config defaults. |

## Intended Flow Rules

### Rule 1: LLM Owns Natural Language Understanding

Natural social or ambiguous language should be delegated:

```text
"how are you"
  -> worker
  -> type=message
  -> text answer from LLM

"رشحلي ريحة حلوة"
  -> worker
  -> tool_call ask_clarification
  -> Dart renders question
```

Do not add Flutter hardcoded social replies for these cases.

### Rule 2: Dart Owns Execution And Truth

The LLM may choose:

```text
tool_call: similar_cheaper
tool_call: ask_clarification
tool_call: reject_visible_products
tool_call: recommend_similar_to_external_profile
```

Dart must:

```text
validate tool name
validate arguments
execute against catalog/context
guard product results
render only safe output
```

### Rule 3: Catalog-Only Cards

Never render:

```text
external perfume profile as a product card
LLM-invented product id
out-of-stock/inactive product
over-budget product except explicit budget-floor acceptance
allergy/excluded-note violation
```

### Rule 4: Local Deterministic Gates Stay Narrow

Local deterministic behavior is valid for:

```text
exact catalog availability
business info from config
direct catalog query
visible-card reference resolution
product context answer from catalog
budget no-match floor acceptance
final guard/no-match/fallback
```

Local deterministic behavior should not become a second chatbot.

### Rule 5: External Perfume Profiles Are Anchors Only

```text
"Do you have Dior Sauvage?"
  -> catalog lookup first
  -> if not catalog item, no availability claim
  -> external profile may anchor alternatives
  -> cards must be catalog products only
```

### Rule 6: Staff Taste Data Is Scoring Metadata

```text
staffTagScores / staffWarnings / staffSalesNotes
  -> ranking/reason support only when reviewed/trusted and coverage complete
  -> generated seed data remains neutral
  -> does not override hard guards
```

## Current Preferred Happy Path

```text
User message
  |
  v
AIChatCubit.sendMessage
  |
  v
TurnDecisionEngine + safety gates
  |
  +--> deterministic local answer only if exact/guarded
  |
  v
DiscoveryService + compact context
  |
  v
AIChatWorkerReplyService
  |
  v
AI Worker structured JSON
  |
  +--> message/ask/answer
  |
  +--> tool_call
          |
          v
       AIChatToolExecutor
          |
          v
       Catalog/scoring/guards
          |
          v
       AIChatToolResultRenderer
  |
  v
AIChatReplyHandler
  |
  v
AIChatState
  |
  v
AIChatPage/widgets
```

## Flow Anti-Patterns To Avoid

```text
Do not put normal conversational copy in AIChatCubit.
Do not let worker product IDs render before FinalRecommendationGuard.
Do not add rule-per-phrase for normal language.
Do not use perfume_knowledge as availability/price/stock truth.
Do not mix staff tags into normal catalog tags.
Do not let generated staff_taste_patch_tool data affect real ranking.
Do not allow local availability intent misclassification to block worker clarification replies.
Do not hide budget-floor exceptions inside cards only; disclose in the message bubble.
```

## Testing Map

| Test Area | Files |
|---|---|
| Cubit and flow regressions | `mobile_app/test/features/ai_chat/presentation/manager/*_test.dart` |
| Tool execution | `ai_chat_tool_executor_test.dart`, `ai_chat_worker_v2_pipeline_test.dart` |
| Resolver/external knowledge | `perfume_reference_resolver_test.dart`, external E2E |
| Staff taste | `staff_taste_scorer_test.dart`, `staff_taste_shadow_validation_test.dart` |
| UI smoke | `mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart` |
| External knowledge UI | `mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart` |
| Worker contract | `backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js` |

## Merge Checklist For AI Chat Flow Changes

Before merging AI Chat flow changes:

```text
1. No new hardcoded chatbot-style replies in Cubit.
2. LLM/tool router handles natural language ambiguity.
3. Dart guards all products before rendering cards.
4. Exact local deterministic cases still work.
5. Worker tests pass.
6. Flutter analyze passes.
7. Targeted Cubit/tool tests pass.
8. UI smoke passes when the change touches user-visible chat flow.
```
