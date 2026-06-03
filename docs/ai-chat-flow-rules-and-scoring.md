# AI Chat Flow, Routing Rules, Scoring, And Guardrails

Last updated: 2026-05-25

This document explains the current AI Chat architecture after the PR8 release-candidate work, targeted hotfixes, UI fixes, and the PR8L competing-route slice.

The core design is:

```text
High-confidence local handling
+ LLM only for ambiguity or semantic planning
+ Dart deterministic execution
+ catalog-grounded scoring
+ guarded rendering
```

The AI worker is not the product authority. The app validates catalog IDs, applies guards, ranks candidates, and decides whether cards may render.

## 1. End-To-End Flow

### 1. User Sends A Message

`AIChatCubit.sendMessage()` creates an active turn with:

- normalized user text
- request ID
- response language
- detected local intent
- current session preferences
- recommendation memory
- availability context

The Cubit logs an outgoing message and starts the turn pipeline.

### 2. Catalog Is Loaded

The app loads the current catalog before deciding final behavior. All cards must come from this catalog.

Important rule:

```text
No catalog product = no product card.
```

### 3. Turn Decision

The turn decision engine and Cubit route gates decide whether the message is:

```text
greeting
business info
direct catalog query
availability query
product context question
recommendation refinement
recommendation request
off-topic / blocked
LLM escalation
```

Decision traces may include:

```text
route / availabilityRoute
action
shouldRenderCards
decisionOwner
clarificationType
llmEscalationReason
finalProductIds
finalGuardDecision
```

### Route Precedence

When more than one route could apply, the safest/highest-confidence route should win. The current operating precedence is:

```text
1. hard safety / prompt injection / allergy lock
2. business info from trusted config
3. direct catalog query
4. explicit availability with a clear product anchor
5. explicit catalog product context answer
6. visible recommendation product-context question
7. recommendation refinement
8. recommendation request
9. LLM escalation for ambiguity / competing routes
10. fallback / clarification
```

This order exists to prevent common misroutes:

```text
product-question must not override recommendation-refinement
availability ambiguity must not override cheaper/similar recommendation intent
direct catalog query should not wait for interpretation worker when local confidence is high
```

### Minimum Local Confidence Contract

Local routes should only execute when all of these are true:

```text
route confidence is high
evidence is explicit
no competing route exists
ambiguityReasons is empty
```

The following thresholds are operating guidelines for future routing work. They are not a claim that every value is fully enforced in code today:

| Route | Minimum local confidence guideline |
|---|---:|
| `business_info` | `>= 0.95` |
| `catalog_query` | `>= 0.90` |
| `availability_exact` | `>= 0.90` |
| `product_context_question` | `>= 0.85` |
| `recommendation_refinement` | `>= 0.85` |

If confidence is lower, or if multiple routes compete, prefer:

```text
ask_clarification
or send_to_llm
```

### 4. Local High-Confidence Routes

The app handles these locally when confidence is high:

- greeting
- business info from trusted config
- direct catalog queries, such as most expensive / cheapest / note-based queries
- clear product-context questions
- visible-card follow-ups
- product reference clarification replies
- strict safety updates, such as exclusions/allergies

Examples:

```text
is Light Blue suitable for work?
=> product_context_question
=> answer_local
=> shouldRenderCards=false

Which one is cheaper?
=> recommendation memory question
=> answer_local
=> shouldRenderCards=false

Most expensive perfume you have
=> direct catalog query
=> execute_tool
=> shouldRenderCards=true
```

High-confidence local routes should be handled before `/api/interpret` when safe:

```text
business info
direct catalog query
exact availability with a local product anchor
explicit product-context answer with a catalog product
visible-card ordinal follow-up
```

This reduces latency and avoids unnecessary worker cost. It must not bypass safety guards.

Direct deterministic queries should not call the worker or `/api/interpret` unless local detector confidence is low.

Examples that should stay local when detected clearly:

```text
most expensive perfume
cheapest perfume
أغلى عطر عندك
أرخص عطر
```

### 5. LLM Escalation

The LLM is used when local logic should not guess.

Examples:

```text
i wwantit too suitable for university
=> route=llm
=> action=send_to_llm
=> llmEscalationReason=natural_language_complexity
```

Allowed LLM role:

```text
understand intent
return structured output
suggest tool/action
```

Forbidden LLM role:

```text
invent products
render cards directly
bypass guards
override strict budget or allergy rules
act as final product authority
```

`send_to_llm` must not render cards directly.

LLM escalation may only return structured semantic output, such as:

```text
intent
tool name
preference patch
clarification need
```

The app must then:

```text
validate
execute deterministic tool/search if needed
apply FinalRecommendationGuard
render only if shouldRenderCards=true
```

Use local when:

```text
exact catalog product + clear question
direct catalog query
business info
availability exact match
visible-card ordinal follow-up
clear recommendation refinement
```

Use LLM when:

```text
typo-heavy or messy message
competing routes
unclear product reference with no visible context
metaphorical scent description
unsupported local route
low-confidence interpretation
```

### 6. Candidate Selection

For recommendation flows, the app builds candidates from:

- local candidate filter
- catalog search engine when enabled
- suitability policy when enabled
- worker-first candidate list when worker is used

The worker receives candidate IDs and preferences, but final rendering still depends on local validation.

### 7. Final Guard And Rendering

Before any product card appears, `FinalRecommendationGuard` checks:

```text
catalog ID exists
product is active
product is in stock
budget policy allows it
excluded notes are not present
medical exclusions are not present
worker product IDs are valid against candidates or fallback policy
matchReason is safe for user display
```

If the route is an answer route:

```text
shouldRenderCards=false
```

No cards should render even if the answer mentions a product.

## 2. Routing Rules

### Route Actions

Current route actions:

```text
answer_local
ask_clarification
send_to_llm
execute_tool
recommend
fallback
```

### Decision Owners

Current decision owner values:

```text
local_gate
llm_router
hard_guard
fallback
```

### Clarification Types

Current clarification types:

```text
product_reference
missing_budget
missing_gender
competing_routes
unclear_intent
```

### LLM Escalation Reasons

Current escalation reason values:

```text
low_confidence
competing_routes
ambiguous_product_reference
natural_language_complexity
missing_context
unsupported_local_route
```

### Product Context Question vs Recommendation Refinement

This was the main PR8L competing-route slice.

Product-context question means:

```text
The user is asking about a specific visible/catalog product.
```

Examples:

```text
is it suitable for university?
does it work for office?
can I wear the first one to work?
is Light Blue suitable for work?
```

Behavior:

```text
explicit product/reference => answer_local
multiple visible products + pronoun => ask_clarification
shouldRenderCards=false
```

Recommendation refinement means:

```text
The user is modifying the desired recommendation set, not asking about one product.
It modifies the active recommendation request, not a visible product card.
```

Examples:

```text
make it suitable for university
i want it suitable for university
change it to office
make them lighter
```

Behavior:

```text
route=recommendation_refinement
action=recommend
shouldRenderCards=true
```

Refinement may update preferences such as:

```text
occasion
season
intensity
budget
notes
gender
tags
```

Examples:

```text
make it suitable for university
=> update occasion=university
=> rebuild/search/rank/guard
=> render cards

make them lighter
=> update intensity=light
=> rebuild/search/rank/guard
=> render cards
```

Messy or typo-heavy competing routes should not be guessed locally.

Example:

```text
i wwantit too suitable for university
=> send_to_llm
=> not product_reference clarification
```

### No Random Product Assumption

When multiple products are visible, the app must not randomly choose one for pronouns like:

```text
it
this
that
ده
دي
```

If the user asks:

```text
is it suitable for work?
```

and there are three visible cards, the app asks:

```text
Which product do you mean? 1. X 2. Y 3. Z
```

If the user replies:

```text
3
acqua
the first one
```

the app resolves the selected visible product and answers locally.

## 3. Product Context Question Flow

### Explicit Catalog Product

Input:

```text
is Light Blue suitable for work?
```

Expected:

```text
route=product_context_question
action=answer_local
shouldRenderCards=false
decisionOwner=local_gate
worker call=no
```

### Visible Product Reference

Input:

```text
does the first one work for office?
```

Expected:

```text
resolve first visible card
answer text only
no new cards
```

### Ambiguous Pronoun

Input:

```text
is it suitable for work?
```

With multiple visible products:

```text
ask_clarification
clarificationType=product_reference
shouldRenderCards=false
```

### Clarification Reply

Input after clarification:

```text
3
acqua
```

Expected:

```text
resolve selected visible product
answer_local
shouldRenderCards=false
```

## 4. Recommendation Flow

A recommendation request can come from:

- direct user request
- preference refinement
- worker ask override
- local fallback after worker timeout
- catalog query that returns product cards

Typical request:

```text
i want a fruity light perfume for men
```

Expected pipeline:

```text
parse preferences
build catalog candidates
optionally call worker
validate worker reply
apply final guard
render guarded cards
```

If the worker returns `ask` but local candidates are strong enough, the app may override with safe recommendations.

If the worker times out, local fallback can render guarded candidates when local readiness is sufficient.

## 5. Suitability Scoring

The suitability policy is moving away from one-off use-case rules and toward generic compatibility scoring.

Current scoring dimensions:

```text
gender compatibility
intensity compatibility
occasion compatibility
time compatibility
season compatibility
notes / tags / fragrance family overlap
budget / premium penalty
negative mismatch penalties
```

### Hard Blocks

Only true safety or catalog integrity issues should hard-block:

```text
inactive product
out of stock
strict budget violation
excluded notes
medical excluded notes / allergy
non-catalog product ID
```

### Soft Penalties

Normal mismatches should usually reduce score, not block:

```text
medium intensity for light request
office product for daily request
winter product when no winter request exists
night/date/party vibe for light daily use
premium product without budget
```

Example:

```text
User wants:
men + light + daily

Product:
men + medium + office

Result:
may stay visible if safe,
but rank lower and show a caveat:
"Not exact on: light intensity and daily use."
```

## 6. Match Reason Rules

User-facing `matchReason` must be:

```text
grounded in product data or user preference
short enough for cards
understandable to normal users
free from internal codes
free from "Suitability:"
free from unsupported claims
```

Allowed examples:

```text
Fits men and daily context.
Matches fruity notes and has a fresh/day profile.
Best available fit with floral and musk notes. Not exact on: daily use.
```

Forbidden examples:

```text
Suitability: medium_for_light_request
heavy_warm_for_light_request
reason_code: weak_office_clean_moderate_fit
```

The final guard may append a user-facing caveat:

```text
Not exact on: daily use.
Not exact on: light intensity.
```

This is only for safe, renderable products. It must not be used to display products that violate hard guards.

If no stronger grounded user-facing reason can be generated for an otherwise safe product, use an honest fallback:

```text
Closest safe catalog match based on your current preferences.
أقرب اختيار آمن من الكتالوج حسب تفضيلاتك الحالية.
```

This fallback must not hide an important mismatch. If a clear mismatch exists, keep the caveat:

```text
Not exact on: ...
```

## 7. Budget And Allergy Rules

### Budget

Strict budget means:

```text
Do not show products over budget.
```

Flexible budget may allow slight upsell only when explicitly permitted by the current budget policy.

Any upsell card must disclose the budget difference.

### Allergy / Medical Exclusions

Medical exclusions are safety constraints.

If the user says:

```text
Vanilla gives me allergy.
```

then later says:

```text
recommend something with vanilla
```

the app must not render vanilla cards. It should answer with a safety lock message or safe alternative.

## 8. Worker Rules

The worker can help with language and structured planning, but the app owns execution.

Worker output must be validated before rendering.

Invalid worker output:

```text
unknown product IDs
external product names as cards
unsafe product IDs
tool calls when tool router is off
raw malformed structured response
```

must not render cards.

Worker timeout behavior:

```text
reasonCode=worker_timeout
fallback local if safe and ready
otherwise ask a grounded clarification
```

Late worker response rule:

```text
If a worker response arrives after the same requestId already rendered fallback,
recovery, or a completed local answer, it must not overwrite visible state unless
the turn is still active and not completed.
```

This prevents race conditions such as:

```text
worker_timeout
local_fallback rendered
worker response received later
```

The late response can be logged for diagnostics, but it must not replace a completed visible reply.

## 9. UI Rendering Rules

Answer route:

```text
shouldRenderCards=false
text answer only
```

An answer route may mention a product by name in text, but it must not attach product cards unless:

```text
action=recommend or action=execute_tool
and shouldRenderCards=true
and FinalRecommendationGuard allows the products
```

Recommendation route:

```text
shouldRenderCards=true
guarded product cards allowed
```

Recommendation scroll behavior:

```text
After recommendation, scroll to the recommendation intro bubble,
not all the way to the input bottom.
```

Card rules:

```text
match reason should fit inside card
card height must match grid height
no raw internal reason text
no external product card
```

Cooldown timer rule:

```text
Cooldown updates must not trigger chat list auto-scroll every second.
```

Known non-AI UI issues should be classified separately from AI routing failures:

```text
Duplicate GlobalKey exceptions
scroll positioning bugs
card height / text clipping issues
keyboard / bottom navigation overlap
```

These may break smoke UX, but they are not evidence of product hallucination, routing failure, or scoring failure.

## 10. Trace Checklist For Smoke Tests

For every important scenario, inspect:

```text
normalizedMessage
route / availabilityRoute
action
shouldRenderCards
decisionOwner
clarificationType
llmEscalationReason
source
worker call yes/no
finalProductIds
matchReason
blockedReasons
```

Important smoke cases:

```text
is Light Blue suitable for work?
is it suitable for work? with 3 cards
does the first one work for office?
i want a fruity light perfume for men
make it suitable for university
i wwantit too suitable for university
Most expensive perfume you have
budget 600 no 900
vanilla allergy then ask vanilla
prompt injection invent product
```

Operational metrics to watch during staging/beta:

```text
misrouting_rate
worker_timeout_fallback_rate
clarification_rate
product_reference_clarification_rate
no_match_rate
guard_block_rate
avg_turn_latency
local_vs_worker_ratio
answer_route_card_render_violations
```

These metrics are diagnostic targets. They do not require a new feature before staging, but PR9 pattern mining should make them easier to compute.

## 11. Current Completion Status

Implemented slices:

```text
PR8K slice:
- suitability penalties reduced hard-block behavior in targeted areas
- internal reasons removed from visible copy
- matchReason caveats added for safe imperfect matches

PR8L slice:
- competing route between product question and recommendation refinement handled
- messy refinement escalates instead of product-reference clarification
- direct catalog query can resolve locally before interpretation

PR8M slice:
- explicit product context answers locally
- ambiguous visible product references ask focused clarification
- clarification by number/name resolves locally

PR8N slice:
- matchReason sanitizer
- no visible "Suitability:" or snake_case reason codes
```

Still incomplete:

```text
PR8L full:
- unified route gate service
- full confidence model
- general llmEscalationReason coverage

PR8M full:
- standalone product context router
- full question type classifier
- broader ambiguous catalog name handling

PR8K full:
- complete generic suitability scoring v2
- reduce remaining use-case-specific scoring rules

PR8O:
- anti-repetition / asked slots / rejected products

PR9:
- pattern mining and aggregation
```

## 12. PR9 Privacy And Redaction Contract

Pattern mining must never store secrets or sensitive personal data.

Do not store:

```text
phone numbers
emails
addresses
payment details
auth tokens
API keys
raw system prompts
raw worker prompts
private user/customer data
```

Store only normalized and preferably redacted text.

Examples:

```text
my phone is 01012345678
=> my phone is [PHONE]

email me at user@example.com
=> email me at [EMAIL]
```

Recommended safe PR9 fields:

```text
normalizedMessageRedacted
route
action
shouldRenderCards
decisionOwner
confidence
clarificationType
ambiguityReasons
llmEscalationReason
LLM intent/tool
fallback reason
final response source
finalProductIds
```

## 13. Safe Defaults And Rollout Matrix

Production should stay conservative unless a separate rollout decision changes it:

```text
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=false
AI_CHAT_USE_SUITABILITY_POLICY=false
AI_CHAT_TOOL_ROUTER_V1=false
AI_CHAT_CATALOG_SEARCH_SHADOW=false
AI_CHAT_ALLOW_GUEST_WORKER=false
```

Recommended staging/beta first step:

```text
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=true
AI_CHAT_USE_SUITABILITY_POLICY=true
AI_CHAT_TOOL_ROUTER_V1=false
```

Tool router should remain beta/off until separate smoke passes.

| Mode | Catalog Search | Suitability | Tool Router | Guest Worker |
|---|---:|---:|---:|---:|
| Conservative production | off | off | off | off |
| Staging beta | on | on | off | controlled |
| Advanced beta | on | on | on | controlled |

Rules:

```text
do not change production defaults without explicit rollout decision
tool router requires independent smoke
guest worker remains off for production/auth-strict paths
npm audit fix stays separate from PR8 rollout
```

## 14. Validation Commands

Targeted checks for app-side changes:

```powershell
dart analyze lib/features/ai_chat test/features/ai_chat
flutter test test/features/ai_chat/presentation/manager/ai_chat_cubit_test.dart
flutter test test/features/ai_chat/presentation/manager/final_recommendation_guard_test.dart
flutter test test/features/ai_chat/presentation/manager/suitability_policy_engine_test.dart
flutter test test/features/ai_chat/presentation/widgets/ai_chat_render_contract_test.dart
flutter test test/features/ai_chat/presentation/widgets/recommended_product_card_test.dart
```

Worker checks only if worker code changes:

```powershell
npm test --prefix backend_and_cloud/workers/perfume-ai-chat-worker
node --check backend_and_cloud/workers/perfume-ai-chat-worker/src/index.js
```
