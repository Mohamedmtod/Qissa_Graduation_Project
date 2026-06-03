# POS Module — Documentation Index

This folder contains the full design and implementation plan for the **Qissa POS Module**.

The POS module supports three product types:
- **Simple products** — ready-made items (bottled perfumes, bakhoor, accessories)
- **Raw materials** — ingredients sold individually or used only in recipes
- **Composite products** — assembled perfumes built from flexible, admin-defined recipes

Built as a Flutter Web screen inside the Admin Dashboard,
backed by a dedicated Cloudflare Worker (`perfume-pos-worker`) and Firestore Transactions.

---

## Document Map

| File | Contents |
|---|---|
| [AGENT_IMPLEMENTATION_GUIDE.md](./AGENT_IMPLEMENTATION_GUIDE.md) | **Start here to implement** — step-by-step guide with pseudocode and test checklists |
| [01-overview-and-decisions.md](./01-overview-and-decisions.md) | Final decisions, architecture, product types, two-phase MVP |
| [02-worker-structure.md](./02-worker-structure.md) | POS Worker folder layout, file responsibilities, error codes |
| [03-flutter-structure.md](./03-flutter-structure.md) | Admin Dashboard Flutter feature layout, screens, widgets, UI rules |
| [04-firestore-data-model.md](./04-firestore-data-model.md) | All collections, fields, composite_recipes schema, stock movements |
| [05-api-contracts.md](./05-api-contracts.md) | HTTP endpoints, request/response shapes, error code reference |
| [06-business-rules.md](./06-business-rules.md) | Business rules, create sale transaction logic, 12 worst-case scenarios |
| [07-flutter-state-management.md](./07-flutter-state-management.md) | All Cubits, PosState, SubmitStatus, CompositeConfigCubit flow |
| [08-todo-and-phases.md](./08-todo-and-phases.md) | Phase 0–9 checklists, implementation order, open questions |

---

## Core Principle

```
Flutter prepares the cart and sends a request.
The Cloudflare POS Worker is the single source of truth.

Flutter never sets the final price.
Flutter never decrements stock.
Flutter never calculates profit as a source of truth.
Flutter never resolves recipe components.
```

---

## MVP Plan

```
MVP 1 — Simple + Raw Material sales (no composite)
MVP 2 — Composite recipe perfumes
```

Start with MVP 1. Build the Worker and transaction first, then the UI.

---

## Related Docs

- [`docs/architecture.md`](../architecture.md) — overall system architecture
- [`docs/current-project-status.md`](../current-project-status.md) — MVP scope and readiness
- [`AGENTS.md`](../../AGENTS.md) — agent operating rules
