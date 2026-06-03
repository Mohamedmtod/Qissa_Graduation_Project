# Project Capabilities

QISSAH is a graduation project built as a multi-part perfume commerce platform. It combines a Flutter customer app, an admin dashboard, backend workers, Firebase services, analysis tools, and test tooling.

## 1. Auth And OTP

The authentication layer covers customer sign-in, account recovery, and access control across the app ecosystem. It is split between Firebase Auth, the Flutter UI, and the dedicated auth worker for OTP reset flows.

What it can do:

- Sign users in and out through Firebase Auth.
- Support customer registration and account recovery flows.
- Keep authenticated sessions available to the mobile app and admin dashboard.
- Resolve user identity for protected Firestore and worker operations.
- Separate customer access from admin access.
- Support a dedicated OTP password reset flow through the auth worker.
- Handle OTP request, verification, and password confirmation steps.
- Apply rate limits and cooldown logic to reduce abuse.
- Enforce password policy checks during reset flows.
- Return safe error states for invalid email, wrong OTP, expired OTP, or weak password cases.
- Keep auth-related logic out of the UI where server-side control is needed.

OTP specifically:

- Starts a reset request for a registered account.
- Sends an OTP through the configured delivery channel.
- Verifies the OTP before password update.
- Blocks reuse or repeated abuse through lockout and rate-limiting logic.
- Completes the reset only after the OTP and new password are valid.

## 2. Mobile App

The mobile app is the customer-facing Flutter application. It is responsible for browsing, shopping, AI-assisted discovery, and order follow-up.

What it can do:

- Register, sign in, and recover accounts.
- Browse the perfume catalog by home sections, categories, search, and details pages.
- View product data such as images, prices, notes, intensity, and related items.
- Save products to wishlist and recently viewed lists.
- Add items to cart, update quantities, and remove items.
- Proceed through checkout and order creation.
- Track orders, view order history, and open order success screens.
- Manage profile settings, language, and password-related actions.
- Show localized Arabic and English content.
- Render AI chat flows that stay grounded in catalog data.
- Display recommendations, availability cards, and follow-up answers.
- Support reusable widgets for sliders, banners, loaders, empty states, and product cards.

Why it stands out:

- AI-assisted perfume guidance.
- Catalog-bounded recommendations instead of generic chatbot replies.
- Local validation before showing product suggestions.
- Shared UI components for a polished shopping experience.

## 3. AI Chat

The AI Chat is not a simple chatbot. It is a hybrid perfume-shopping assistant that combines deterministic app logic, a structured LLM worker, catalog filtering, safety guards, and UI rendering controls.

What it can do:

- Understand perfume requests in Arabic and English.
- Read preferences such as gender, budget, notes, season, occasion, intensity, and use case.
- Ask smart clarification questions when the request is incomplete instead of returning a generic reply.
- Infer likely scent direction from context, such as fresh and light for university use.
- Recommend only products that exist in the real catalog.
- Use Worker v2 as a structured planner, where the LLM suggests the response type, message, commands, and product IDs while the Flutter app keeps validation and rendering control.
- Re-check and filter all recommendations locally before showing them.
- Block invalid, unavailable, over-budget, excluded-note, or unsafe products from appearing.
- Rank catalog candidates with deterministic suitability scoring instead of one-off rules for every scenario.
- Respect strict budget limits, including "do not show anything above X" style requests.
- Handle excluded notes and allergy-related safety constraints carefully.
- Answer product availability questions directly from the catalog, including price.
- Answer clear product-context questions as text-only local answers, such as whether a visible or named product works for office, gym, daily use, or another context.
- Ask which product the user means when a visible-card reference is ambiguous, instead of guessing.
- Suggest cheaper alternatives to an available product while staying grounded in catalog data.
- Remember the currently visible recommendation cards so users can ask follow-up questions like "Which one is cheaper?" or "Tell me more about the second one."
- Compare visible products by price, intensity, use case, and general scent profile.
- Answer business questions from trusted app configuration only, such as payment methods, contact information, or discounts.
- Reject prompt injection attempts, such as instructions to ignore rules or invent products outside the catalog.
- Prevent product hallucination by never creating perfumes that do not exist.
- Return safe no-match or fallback responses when no suitable recommendation exists.

How it works:

- The LLM is used for natural language understanding and planning.
- The final decision is controlled by the Flutter app through route/action decisions, catalog validation, suitability scoring, final recommendation guards, answer grounding, reason sanitization, and safe rendering.
- This makes the AI Chat more reliable than a normal LLM-only chatbot.

## 4. Admin Dashboard

The admin dashboard is the business operations interface for the project. It is built to manage products, orders, inventory, content, and analytics.

What it can do:

- Sign in admins and enforce access control.
- View operational dashboards and summary metrics.
- Manage products, content, and inventory workflows.
- Track and update orders through admin flows.
- Review finance-related summaries and reports.
- Inspect AI-related insights and operational signals.
- Manage shipping zones and delivery-related setup.
- Handle user-facing support and administrative records.
- Support Arabic and English localization in the admin UI.
- Use shared contracts so the admin dashboard stays aligned with the customer app and backend data model.

Why it matters:

- It turns the project from a simple store into a full operations system.
- It gives the reviewer a clear business side of the platform.
- It keeps operational data in one place instead of spread across the mobile app.

## 5. Backend And Cloud

The backend and cloud layer provides the secure runtime foundation for the whole platform.

What it can do:

- Authenticate users through Firebase Auth.
- Store and query business data in Firestore.
- Enforce security rules and access control.
- Process orders through Cloudflare Workers.
- Handle AI chat requests through the AI worker.
- Support auth-related worker flows where needed.
- Keep order and availability flows consistent with the catalog.
- Provide backend hooks for analytics, reporting, and operational automation.
- Support local development and emulator-based checks.

Why it matters:

- It keeps sensitive logic off the client.
- It separates customer actions from server-side business rules.
- It reduces the chance of stock or order inconsistency.
- It supports a more realistic graduation-project architecture.

## 6. AI And Analytics Tools

This part of the project contains helper tools for AI, recommendations, parsing, and analysis tasks.

What the tools can do:

- Generate and inspect AI chat scenarios.
- Decode and analyze AI chat events.
- Support recommendation-related experiments and checks.
- Help with live runners and test data generation.
- Support rule-based or data-driven analysis scripts.
- Assist with debugging and validation around AI behavior.

Why these tools exist:

- They make the AI and recommendation system easier to test.
- They help reproduce edge cases before committee review.
- They keep debugging and analysis outside the production app flow.

## 7. Testing Tools

The testing tools folder contains scripts and utilities for running the project in a controlled way.

What the tools can do:

- Start the local test stack.
- Run main app checks.
- Run admin dashboard checks.
- Run full-project test passes.
- Run worker-level validation scripts.
- Run AI chat live scenarios and report results.
- Decode and summarize test outputs.

Why they matter:

- They make it easier to verify the project before submission.
- They centralize repeatable commands for the reviewer.
- They reduce manual setup during demo preparation.

## 8. Summary

The project is more than a storefront. It is a controlled perfume-commerce system with:

- customer auth and OTP recovery
- AI-assisted shopping
- admin operations
- backend workers and Firestore rules
- analysis tools
- repeatable test tooling

The final product is reliable because the LLM assists with language understanding, but the Flutter app and backend rules keep the final decisions grounded and safe.
