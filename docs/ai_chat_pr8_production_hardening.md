# AI Chat PR8I Production Hardening

## Scope

PR8I is hardening only. It does not add ranking changes, prompt rewrites, new UX, or default enablement for PR8 experimental paths.

## Production flag matrix

Recommended production defaults:

```text
ENFORCE_AUTH=true
AI_CHAT_ALLOW_GUEST_WORKER=false
AI_CHAT_TOOL_ROUTER_V1=false
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=false
AI_CHAT_USE_SUITABILITY_POLICY=false
AI_CHAT_CATALOG_SEARCH_SHADOW=false
```

Staging/demo can opt in deliberately:

```text
AI_CHAT_TOOL_ROUTER_V1=true
AI_CHAT_USE_CATALOG_SEARCH_ENGINE=true
AI_CHAT_USE_SUITABILITY_POLICY=true
```

## Safety gates

Before production-ready:

```text
No product hallucination.
No fake price or business info.
No strict budget violation.
No allergy reversal.
No external product rendered as a card.
No user-visible permission-denied.
No raw timeout/worker exception shown to the user.
No invalid tool_call crash or direct render.
```

## Current hardening coverage

- Worker requests require auth unless guest worker is explicitly allowed.
- Guest worker requests are off by default in release builds.
- Worker network timeout is classified as `worker_timeout` and returns null for local fallback handling.
- Invalid worker `tool_call` replies are rejected as parse errors and do not render.
- PR8 runtime flags are off by default and resettable in tests.
- Firestore `permission-denied` in non-critical telemetry and perfume knowledge lookup is swallowed into safe fallback/log-only behavior.

## Known follow-up

After local `npm install` in `backend_and_cloud/workers/perfume-ai-chat-worker`, `npm audit` reports:

```text
6 vulnerabilities
4 moderate
2 high
```

This was not changed in PR8I. Do not run `npm audit fix` blindly before release; handle it as a separate dependency/security review because it can change the worker dependency tree.
