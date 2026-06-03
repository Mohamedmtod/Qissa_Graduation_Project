# AI Chat Capabilities

The AI Chat is not a simple chatbot. It is a hybrid perfume-shopping assistant that combines deterministic app logic, a structured LLM worker, catalog filtering, safety guards, and UI rendering controls.

## Current Audited Count

The official capability count is maintained in:

- [`ai-chat-capability-audit.md`](ai-chat-capability-audit.md)

Current audited totals:

| Metric | Count |
|---|---:|
| Total capabilities | 102 |
| Verified | 102 |
| Partial | 0 |
| Unverified | 0 |
| Deferred | 0 |
| Allowed tools | 16 |

## Summary Of What The AI Chat Can Do

- Understand perfume requests in Arabic and English.
- Read preferences such as gender, budget, notes, season, occasion, intensity, and use case.
- Ask smart clarification questions when the request is incomplete instead of returning a generic reply.
- Infer likely scent direction from context, such as fresh and light for university use.
- Recommend only products that exist in the real catalog.
- Use Worker v2 as a structured planner, where the LLM suggests the response type, message, commands, and product IDs while the Flutter app keeps validation and rendering control.
- Re-check and filter all recommendations locally before showing them.
- Block invalid, unavailable, over-budget, excluded-note, or unsafe products from appearing.
- Rank catalog candidates with deterministic suitability scoring so normal context mismatches affect order without turning into endless one-off rules.
- Respect strict budget limits, including "do not show anything above X" style requests.
- Handle excluded notes and allergy-related safety constraints carefully.
- Answer product availability questions directly from the catalog, including price.
- Answer product-context questions directly when the product is clear, such as "is Light Blue suitable for work?", without starting a new recommendation or showing new cards.
- Ask a focused clarification when a product reference is ambiguous, such as "Which product do you mean? 1. Light Blue 2. Acqua di Gio 3. Si".
- Suggest cheaper alternatives to an available product while staying grounded in catalog data.
- Remember the currently visible recommendation cards so users can ask follow-up questions like "Which one is cheaper?" or "Tell me more about the second one."
- Compare visible products by price, intensity, use case, and general scent profile.
- Answer business questions from trusted app configuration only, such as payment methods, contact information, or discounts.
- Reject prompt injection attempts, such as instructions to ignore rules or invent products outside the catalog.
- Prevent product hallucination by never creating perfumes that do not exist.
- Return safe no-match or fallback responses when no suitable recommendation exists.

This file is a summary only. Use the audit matrix for implementation evidence and status.

## Additional Supporting Guarantees

The audited count above intentionally tracks core AI Chat capabilities. The system also has verified supporting guarantees that should not be mixed into the product-facing count:

| Area | Status | Notes |
|---|---|---|
| Session memory management | Present | Conversation memory tracks visible products, focused product, rejected products, last no-match, external profile anchors, and pending clarifications. |
| Controlled memory updates | Present | Tool execution can update recommendation memory in a controlled result contract instead of relying on raw message text only. |
| Stale-context protection | Present | Strong pivots, new recommendation turns, and local route decisions prevent old visible-card context from hijacking fresh requests. |
| Async tool execution safety | Present | Tool execution supports async handlers and returns structured fallback/validation results instead of rendering random output on failure. |
| Tool contract completeness | Present | The 16 allowed tools are represented in compact context and covered by executor/contract tests. |
| Preference refinement execution | Present | `update_preferences_and_recommend` applies the preference patch and runs catalog recommendation in the same turn. |
| Egyptian Arabic ambiguity | Present | "ريحة حلوة" is treated as ambiguous between sweet/sugary and pleasant/beautiful; "جميلة ولطيفة" does not become a sweet-note request. |
| Answer grounding | Present | Text answers are guarded against unsupported product, price, stock, note, and schema/system-prompt claims. |
| Staff taste governance | Present | Staff taxonomy, staff tag scores, warnings, coverage, review status, guarded ranking, and generated-seed blocking are implemented. |
| Admin feedback analytics | Present | Admin AI Insights includes read-only AI feedback analytics from `ai_feedback` and `ai_feedback_analysis` summaries. |
| Release log privacy | Present | AI Chat repository logging redacts raw user text in release mode and uses request IDs/status metadata for diagnosis. |
| Traceability | Present | AI Chat emits route/source/tool/guard/final product traces for debugging without depending on free-form LLM text. |

Postponed or external production-readiness items remain outside the AI Chat capability count:

- Worker dependency/audit verification.
- Firestore rules hardening beyond current tests.
- Production deploy checks.
- Human review of generated staff taste seed data.

## How The System Works

The LLM is used for natural language understanding and planning, but the final decision is controlled by the Flutter app through:

- catalog validation
- route/action decisions such as `answer_local`, `ask_clarification`, `execute_tool`, or `recommend`
- explicit render control through `shouldRenderCards`
- final recommendation guards
- deterministic suitability scoring
- user-facing reason sanitization
- answer grounding
- safe rendering

This makes the AI Chat more reliable than a normal LLM-only chatbot.
