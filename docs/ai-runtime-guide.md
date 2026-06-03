# AI Runtime Guide

This file consolidates the AI navigation, worker contract, governance, and stabilization notes.

## 1. Where To Start

Use this guide when you need to understand how the AI subsystem works at runtime.

Recommended order:

1. `current-project-status.md`
2. `current-test-status.md`
3. `ai-runtime-guide.md`
4. `project-map.md`

## 2. Current AI Runtime Model

The AI subsystem is not a plain chatbot. It is a controlled perfume assistant that uses:

- catalog-bounded candidate selection
- structured worker output
- local validation in Flutter
- fallback handling when no safe answer exists

The app keeps control over the final rendering decision. The worker helps with planning, but it does not get to invent products or override app-side safety checks.

## 3. Worker Contract Summary

The AI worker accepts a perfume request with optional preferences and candidate products, then returns a structured response such as:

- recommend
- ask
- answer
- info

Important contract rules:

- requests must stay grounded in the actual catalog
- the worker output must remain structured
- product IDs must refer to real products
- response metadata is used for traceability and observability

## 4. Governance And Safety

The AI data policy is built around the following ideas:

- do not log secrets or authorization headers
- keep operational access limited
- do not store unnecessary personal data
- keep worker behavior aligned with the current app policy
- treat older prompt experiments as historical unless explicitly promoted

The system should reject prompt injection attempts, invented products, and unsupported business claims.

## 5. Stabilization Notes

The AI chat history shows repeated hardening around:

- answer grounding
- budget filtering
- availability handling
- follow-up resolution
- catalog safety
- text normalization
- structured response repair

These notes are historical, but they explain why the current runtime is more defensive than a simple LLM wrapper.

## 6. Handoff Note

If you are continuing AI work in the codebase, prefer:

- the current project status
- the worker contract
- the AI capabilities summary
- the live code in `lib/features/ai_chat/`

Older worktree handoff notes are retained only as background context.

