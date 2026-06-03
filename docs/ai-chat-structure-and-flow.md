# AI Chat Structure And Flow

This document maps the AI Chat files, responsibilities, and the expected runtime flow.

Core principle:

```text
LLM understands the user and may generate natural replies or choose tools.
Dart validates and executes tools.
Catalog is the only source of truth for products, price, stock, and cards.
Guards decide what can be rendered.
UI renders only validated app state.
```

## High-Level Structure

```text
User
  |
  v
AI Chat UI
  |
  v
AIChatCubit
  |
  +--> local safety / deterministic commerce checks
  |
  +--> compact context builder
  |
  v
AI Worker / LLM
  |
  +--> natural message
  +--> ask question
  +--> tool_call
  +--> grounded recommendation command
  |
  v
Dart validation and tool execution
  |
  v
Catalog search / resolver / scorer / guards
  |
  v
AIChatReplyHandler
  |
  v
AIChatState -> UI bubbles and catalog cards
```

## Golden Rules

```text
1. LLM can understand language, ask naturally, and choose tools.
2. LLM must not invent available products, prices, stock, or product cards.
3. Dart executes tools and validates all IDs before rendering.
4. Catalog products are the only renderable cards.
5. perfume_knowledge and external profiles are scent anchors only.
6. Local deterministic logic is allowed for safety, exact catalog operations, and guardrails.
7. Local deterministic logic should not become conversational hard-coded scripts.
8. AIChatCubit should orchestrate; domain logic should live in services.
```

## Main File Map

### UI Layer

```text
mobile_app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart
```

Main AI Chat screen. Owns the visible chat page, input area, message list, refresh action, and state binding.

```text
mobile_app/lib/features/ai_chat/presentation/widgets/chat_message_bubble.dart
```

Renders user and assistant text bubbles. It should not decide business logic.

```text
mobile_app/lib/features/ai_chat/presentation/widgets/recommended_product_card.dart
```

Renders catalog product cards after they pass the final guards. It must never render external perfume profiles as products.

### Public Contracts And Models

```text
mobile_app/lib/features/ai_chat/domain/entities/ai_chat_message.dart
```

UI/domain message model used by the chat state.

```text
mobile_app/lib/features/ai_chat/data/models/ai_chat_reply.dart
```

Normalized app reply contract after worker/local validation. It represents answer, ask, recommendation, no-match, fallback, or availability-like responses.

```text
mobile_app/lib/features/ai_chat/data/models/ai_chat_tool_call.dart
```

Tool call model and tool names. Any new tool should be added here, then implemented in the executor and worker schema.

```text
mobile_app/lib/features/ai_chat/data/models/ai_chat_structured_reply.dart
mobile_app/lib/features/ai_chat/data/models/ai_chat_reply_validator.dart
```

Parse and validate structured worker responses before the app trusts them.

```text
mobile_app/lib/features/ai_chat/data/models/session_preferences.dart
```

Current preference state: gender, budget, season, occasion, time, intensity, notes, excluded notes, medical exclusions, and tags.

```text
mobile_app/lib/features/ai_chat/data/models/recommendation_memory.dart
```

Conversation memory for visible products, focused product, rejected products, previous no-match, pending clarification, last external profile, and related follow-up context.

```text
mobile_app/lib/features/ai_chat/data/models/ai_chat_compact_conversation_context.dart
```

Small structured context sent to the worker. It helps the LLM resolve "it", "these", cheaper follow-ups, visible products, pending clarifications, and external profile anchors without guessing.

```text
mobile_app/lib/features/ai_chat/data/models/preference_patch.dart
```

Structured preference updates coming from interpretation/tool execution.

```text
mobile_app/lib/features/ai_chat/data/models/perfume_knowledge_profile.dart
mobile_app/lib/features/ai_chat/data/models/external_perfume_candidate.dart
mobile_app/lib/features/ai_chat/data/models/external_perfume_lookup_result.dart
```

External perfume knowledge models. These are for scent understanding only, not product availability.

### Repository Boundary

```text
mobile_app/lib/features/ai_chat/data/repos/ai_chat_repo.dart
```

Boundary for AI worker calls, catalog access, persistence, perfume knowledge lookups, feedback, and related data operations. The Cubit should call this instead of reaching into backend details directly.

### Cubit And Turn Orchestration

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit.dart
```

Main orchestrator. It should coordinate the turn, not own every rule. It loads catalog context, calls decision services, sends worker requests, invokes tool execution, applies guards, and emits state.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_turn_flow.dart
```

Turn lifecycle helpers: preparing active turns, handling incoming messages, and sequencing major decisions.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_recommendation_flow.dart
```

Recommendation path: candidate search, local fallback, worker recommendation handling, and final product preparation.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_worker_flow.dart
```

Worker path: building requests, handling worker responses, fallback behavior, and late-response safety.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_availability_flow.dart
```

Availability and exact catalog product checks. This should remain catalog-grounded and must not use external profiles as availability proof.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_context_followups.dart
```

Follow-up handling based on previous visible/focused products and conversation memory.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_cubit_quality_guards.dart
```

Quality and safety guards around turn handling and rendering decisions.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_state.dart
```

State emitted to the UI: messages, status, recommendation products, selected context, and metadata.

### Turn Decision And Interpretation

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_turn_decision_engine.dart
```

Initial route decision. It decides whether a message looks like greeting, recommendation, availability, catalog query, product question, or clarification.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_turn_service.dart
```

Shared turn-level utilities and structured flow helpers.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_interpretation_service.dart
```

Optional interpretation layer for extracting intent and preference patches. It should not override safer worker/tool flow with weak guesses.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_worker_reply_service.dart
```

Worker reply handling and normalization support.

### Tool Routing And Execution

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart
```

Local deterministic router for high-confidence commerce follow-ups, such as reject visible products, cheaper follow-up, similar cheaper, and budget-floor acceptance.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart
```

Executes validated tool calls. It is the main Dart tool boundary. It should reject ungrounded product IDs, ungrounded external profile IDs, invalid tool arguments, and unsafe render requests.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_tool_result_renderer.dart
```

Converts tool execution results into app replies/messages after validation.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart
```

Final rendering bridge. It adds assistant messages, recommendation products, ask messages, no-match messages, and availability answers to state.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart
```

Normalizes reply text and shape before display.

### Search, Ranking, And Guards

```text
mobile_app/lib/features/ai_chat/presentation/manager/catalog_search_engine.dart
```

Catalog search and candidate discovery from preferences, notes, tags, gender, season, occasion, budget, and related signals.

```text
mobile_app/lib/features/ai_chat/presentation/manager/catalog_facet_index.dart
```

Indexes catalog facets for matching. Staff facets should stay separate from normal catalog tags.

```text
mobile_app/lib/features/ai_chat/presentation/manager/catalog_product_matcher.dart
```

Product matching helpers for product names, aliases, and catalog references.

```text
mobile_app/lib/features/ai_chat/presentation/manager/local_candidate_filter.dart
```

Filters local candidate sets before scoring/rendering.

```text
mobile_app/lib/features/ai_chat/presentation/manager/suitability_policy_engine.dart
```

Suitability scoring and explanation policy. It should rank by meaningful preferences while preserving hard blocks.

```text
mobile_app/lib/features/ai_chat/presentation/manager/final_recommendation_guard.dart
```

Final gate before cards are shown. It blocks inactive, out-of-stock, over-budget strict violations, allergy/exclusion violations, and non-catalog items.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_answer_grounding_guard.dart
```

Grounding guard for text answers that refer to products, prices, stock, or catalog facts.

```text
mobile_app/lib/features/ai_chat/presentation/manager/staff_taste_scorer.dart
```

Staff Taste Intelligence scorer. Current generated data from patch tools should remain neutral unless reviewed by real admin workflow.

```text
mobile_app/lib/features/ai_chat/presentation/manager/scent_profile_scorer.dart
mobile_app/lib/features/ai_chat/presentation/manager/reference_product_similarity_ranker.dart
```

Similarity scoring for scent profiles, catalog anchors, and external profile anchors.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart
mobile_app/lib/features/ai_chat/presentation/manager/budget_amount_parser.dart
```

Budget extraction and budget policy. Strict budget must not be exceeded unless the user explicitly accepts the budget-floor exception.

### Product Context, References, And External Knowledge

```text
mobile_app/lib/features/ai_chat/presentation/manager/perfume_reference_resolver.dart
```

Resolves catalog and external perfume references. Ambiguous brand or series queries should ask clarification, not auto-select.

```text
mobile_app/lib/features/ai_chat/presentation/manager/mentioned_product_resolver.dart
mobile_app/lib/features/ai_chat/presentation/manager/recommendation_reference_resolver.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver.dart
```

Resolve "first one", "it", partial names, visible products, and recommendation-memory references.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart
```

Builds grounded text answers for product-context questions using catalog/recommendation memory.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_product_context_signals.dart
```

Detects product-context question signals.

### Local Safety, Copy, And Normalization

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_normalizer.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_normalization_dictionary.dart
```

Language normalization, aliases, Arabic/English cleanup, and known phrase mapping.

```text
mobile_app/lib/features/ai_chat/presentation/manager/local_intent_parser.dart
```

Local intent and preference extraction for clear signals. It should not replace the LLM for nuanced conversational understanding.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_input_interceptor.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_interceptor_copy.dart
```

Safety and quality intercepts for hard cases. These should stay limited to high-confidence safety/business constraints, not broad conversational scripts.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_copy_resolver.dart
```

Shared user-facing copy helpers for fallback and safety messages.

```text
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_business_info_responder.dart
mobile_app/lib/features/ai_chat/presentation/manager/ai_chat_local_catalog_command_handler.dart
```

Local deterministic answers for business info and direct catalog commands such as cheapest/most expensive.

### Worker

```text
backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
```

Cloudflare Worker for AI chat. It exposes chat/interpret routes, builds the model prompt, validates/sanitizes output, defines allowed tool behavior, and returns structured replies.

```text
backend_and_cloud/workers/perfume-ai-chat-worker/wrangler.toml
```

Worker configuration and environment bindings. Treat as sensitive-zone config.

```text
backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js
```

Worker prompt/normalization contract tests.

## Expected Runtime Flow

### 1. Message Enters UI

```text
User sends message
  -> ai_chat_page.dart
  -> AIChatCubit receives message
  -> message appended as user bubble
```

The UI should not decide intent, product availability, or cards.

### 2. Cubit Prepares Turn

```text
AIChatCubit
  -> normalize text and language
  -> load catalog
  -> read current SessionPreferences
  -> read RecommendationMemory
  -> build request/turn metadata
```

### 3. Turn Decision

```text
AIChatTurnDecisionEngine
  -> classify obvious route
  -> exact catalog availability can stay local
  -> business info can stay local
  -> direct catalog query can stay local
  -> nuanced social / ambiguous / recommendation language goes to worker when enabled
```

Important:

```text
"how are you" should go to worker for a natural social answer.
"رشحلي ريحة حلوة" should let worker/tool flow resolve whether "حلوة" means sweet or generally nice.
```

### 4. Compact Context Sent To Worker

```text
AIChatCompactConversationContext
  -> current preferences
  -> visible products
  -> last focused product
  -> last recommendation ids
  -> rejected product ids
  -> pending clarification
  -> last external profile
  -> allowed tools
```

The worker receives enough context to choose the correct tool without guessing.

### 5. Worker Response

The worker can return:

```text
message
  -> natural answer, no cards

ask
  -> clarification question, no cards

tool_call
  -> Dart validates and executes the tool

recommendation command
  -> product IDs must be grounded in candidate/catalog context, then guarded
```

The worker should not directly force UI cards.

### 6. Tool Execution

```text
AIChatToolExecutor
  -> validates tool name and arguments
  -> validates product IDs / externalProfileId grounding
  -> executes catalog search, cheaper follow-up, reject-visible, similar-cheaper, external-profile similarity, etc.
  -> returns structured AIChatToolExecutionResult
```

Tool result statuses:

```text
success
needs_clarification
no_results
blocked_by_guard
validation_failed
```

Only safe `success + recommend` can continue to card rendering.

### 7. Guarding

```text
FinalRecommendationGuard
  -> active product only
  -> in stock only
  -> catalog product only
  -> budget strict respected
  -> allergy/excluded notes blocked
  -> external profiles blocked from card rendering
```

### 8. Rendering

```text
AIChatReplyHandler
  -> answer: text bubble only
  -> ask: question bubble only
  -> availability: grounded text answer
  -> recommend: assistant text + guarded catalog cards
  -> noMatch/fallback: safe text, no random cards
```

## Key Scenario Flows

### Social Conversation

```text
User: how are you?
  -> Cubit builds context
  -> Worker generates natural answer
  -> ReplyHandler renders answer bubble
  -> No cards
```

Expected behavior:

```text
The assistant answers socially, then invites the user to ask about perfume.
```

### Egyptian Arabic "حلوة" Ambiguity

```text
User: رشحلي ريحة حلوة
  -> Worker detects ambiguous "حلوة"
  -> Worker returns tool_call: ask_clarification
  -> Dart renders clarification
```

Expected clarification:

```text
تقصد حلوة بمعنى مسكرة/sweet، ولا جميلة ولطيفة عمومًا؟
```

If user says:

```text
جميلة ولطيفة
```

Expected:

```text
Interpret as pleasant/elegant/clean, not sugary sweet.
Continue with a relevant question or recommendation depending on available preferences.
```

### Normal Recommendation

```text
User: I want a light fruity perfume for men
  -> preferences extracted
  -> catalog search
  -> worker/tool may refine
  -> final guard
  -> catalog cards
```

### Product Context Question

```text
User: is the first one suitable for work?
  -> resolve visible product
  -> answer from catalog/recommendation memory
  -> no cards
```

### Availability

```text
User: Do you have Light Blue?
  -> exact catalog product availability
  -> answer from catalog price/stock
  -> no external profile proof
```

### External Reference

```text
User: something like Dior Sauvage
  -> resolve external profile
  -> external profile used as scent anchor
  -> catalog similarity search
  -> final guard
  -> catalog-only cards
```

### Cheaper Follow-Up

```text
User: similar but cheaper
  -> resolve anchor from focused product / visible product / external profile
  -> apply price ceiling only when grounded
  -> final guard
  -> catalog cards
```

## Tool Addition Checklist

When adding a new tool:

```text
1. Add tool name/schema in ai_chat_tool_call.dart.
2. Add worker allowed tool schema/prompt instructions.
3. Implement validation and execution in ai_chat_tool_executor.dart or a delegated service.
4. Ensure result uses AIChatToolExecutionResult.
5. Add guard path before rendering cards.
6. Add compact context fields only if needed.
7. Add unit tests for validation and execution.
8. Add Cubit/pipeline test if it affects conversation flow.
9. Add E2E only if it affects visible UX.
```

## Anti-Patterns To Avoid

```text
Do not add broad hard-coded social replies in Cubit.
Do not add one-off phrase scripts for every expected user sentence.
Do not let worker product IDs bypass Dart validation.
Do not render cards from external profiles.
Do not use perfume_knowledge for availability, stock, or catalog price.
Do not mix staffTagScores into normal catalog tags.
Do not grow AIChatCubit with new domain logic when a small service can own it.
Do not show internal trace codes to users.
```

## Test Map

### Mobile Unit / Flow Tests

```text
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_cubit_conversational_policy_test.dart
```

Conversational policy and social-worker routing.

```text
mobile_app/test/features/ai_chat/presentation/manager/ai_chat_tool_executor_test.dart
```

Tool execution contract and guard behavior.

```text
mobile_app/test/features/ai_chat/presentation/manager/staff_taste_scorer_test.dart
```

Staff taste scoring and generated-data guard.

```text
mobile_app/test/features/ai_chat/presentation/manager/perfume_knowledge_20_scenarios_test.dart
mobile_app/test/features/ai_chat/presentation/manager/perfume_knowledge_5_scenarios_test.dart
```

External perfume knowledge behavior.

### Mobile E2E

```text
mobile_app/integration_test/ai_chat_e2e_ui_smoke_test.dart
```

Main AI Chat UI smoke. Covers social reply, clarification, recommendations, rejection, cheaper follow-up, budget floor, availability, and Arabic catalog query.

```text
mobile_app/integration_test/ai_chat_external_knowledge_e2e_test.dart
```

External knowledge smoke.

### Worker Tests

```text
backend_and_cloud/workers/perfume-ai-chat-worker/test/chat-normalization.test.js
```

Worker prompt and normalization contract tests.

## Maintenance Notes

```text
AIChatCubit should stay orchestration-focused.
Worker should own language understanding and natural reply generation when safe.
Dart should own validation, tool execution, catalog truth, and rendering control.
Every new render path should answer: where is it grounded, what guard protects it, and what test proves it?
```

