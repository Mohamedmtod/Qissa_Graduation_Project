# Current Project Status

Last updated: 2026-05-25
Purpose: single source of truth for the defense/MVP stabilization pass.

## Related Docs

- [`AGENTS.md`](../AGENTS.md): workflow rules, safety policy, and agent operating constraints.
- [`docs/REPO_MAP.md`](./REPO_MAP.md): quick repository navigation and high-level area map.

## Agent workflow validation

- Docs-only edits have been validated.
- `mobile_app` scoped edits have been validated.
- Backend/cloud docs-only cleanup has been validated.

## Current Verdict

The project is a strong graduation MVP candidate, not a production-ready system. The defense build should be treated as a catalog-bounded perfume commerce app with AI-assisted recommendations, OTP reset, order processing through workers, and an admin dashboard.

The project must stay frozen except for bug fixes, security cleanup, docs corrections, and test stabilization.

## Latest Repair Pass

Completed so far in the 2026-05-01 repair pass:

- Fixed the AI Chat out-of-stock availability regression so an exact out-of-stock product returns an availability card instead of falling back to an ask state.
- Fixed admin dashboard Firestore tests that used Mocktail named argument matchers incorrectly.
- Fixed the AI Chat budget/upsell integration test mock setup and aligned it with current `conversion_upsell_*` telemetry event names.
- Removed the orders worker unit-test module-type warning without changing the worker runtime scripts.
- Moved the local Firestore emulator port to `127.0.0.1:8085` so rules tests do not conflict with common app/dev-server use of port 8080.
- Removed local service-account and `.dev.vars` files found in the workspace.
- Removed the later-discovered `.local/serviceAccountKey.json` file and the local `secret/` folder.
- Expanded `.gitignore` to keep service-account files, camelCase service account files, `.local`, `.dev.vars`, `.wrangler`, `.env`, PEM, and key files out of the project tree.
- Hardened worker config defaults for defense by enabling AI worker auth enforcement and replacing wildcard CORS with explicit local/demo origins.
- Refreshed the `docs` folder on 2026-05-01 so current docs are clearly separated from historical plans, audits, spikes, and reports.
- Refreshed the admin dashboard documentation on 2026-05-13 so its security, architecture, and integration notes stay aligned with the current routes and shared schema contracts.
- Updated AI chat follow-up routing and telemetry/analysis typing on 2026-05-14:
	- Availability follow-ups now keep current context by default and only switch context on explicit switch-intent phrases.
	- Availability turns remain typed as `availability` in analysis transcript compaction.
	- Availability card rendering now emits `availability_answer_shown` telemetry for clearer observability.
- Completed the AI Chat PR8 conservative MVP candidate pass and post-RC targeted hotfix on 2026-05-25:
	- Product-context questions now answer locally without rendering new recommendation cards.
	- Ambiguous visible product references now ask a focused clarification instead of assuming a random card.
	- Numeric/name clarification replies resolve to the selected visible product locally.
	- Direct Arabic catalog queries such as `أغلى عطر عندك` resolve locally before interpretation-worker escalation.
	- Suitability policy now uses generic scoring/penalties for normal context fit while keeping hard blocks for safety and render constraints.
	- User-facing recommendation reasons are sanitized to hide internal `Suitability:` and snake_case reason codes.

Final automated verification in this repair pass:

- `flutter analyze`: PASS
- `flutter test`: PASS
- admin `flutter analyze`: PASS
- admin `flutter test`: PASS
- auth worker `npm test`: PASS
- AI worker `npm test`: PASS
- orders worker `npm test`: PASS
- Firestore rules emulator command `firebase emulators:exec --only firestore "npm --prefix functions run test:rules"`: PASS
- `flutter test integration_test/ai_chat_budget_upsell_test.dart`: PASS
- AI chat business info live runner: PASS, `14/14`
- AI chat 20 memory live runner: PASS, `20/20`
- AI chat 40 live runner: PASS, `40/40`
- AI chat 100 live runner: PASS, `132/132`

Security scan after cleanup:

- `service-account*.json` files in the workspace: none found
- `serviceAccount*.json` files in the workspace: none found
- local `secret/` folder: absent
- `.dev.vars` files in the workspace: none found
- private-key pattern scan outside `node_modules`/build output: only parser/source-code references found, no raw key material found

## Ready For Defense Demo

- Firebase email/password authentication flow, subject to final manual QA.
- OTP reset architecture through the auth worker, subject to real Resend delivery verification.
- Product catalog, details, cart, checkout, order history, and pending-order cancellation.
- Orders worker as the authoritative stock/order mutation path.
- AI Chat for curated catalog-bounded recommendation and availability scenarios.
- Latest AI chat regression suites are green on the current build, including PR8 targeted Cubit, suitability, catalog query, final guard, render contract, and worker-pipeline suites. Earlier business-info, memory, realistic 40-scenario, and full 100-scenario runs are also retained as regression evidence.
- Admin dashboard screens backed by Firestore services.
- Arabic/English localization for core flows.

## Not Production Ready

- No production payment gateway.
- AI latency is not guaranteed.
- AI quality is materially improved for catalog-bounded product questions and recommendation flows, but broad production rollout of PR8 flags still requires staging UI smoke and monitoring.
- Automated retention for AI chat/session data is not implemented.
- Secrets were found in the workspace during review and must be considered exposed; rotate them before sharing or deployment.
- Full manual QA on real device/network is still required.

## Demo-Safe AI Prompts

- `Do you have Cedar Class 01?`
- `Recommend a fresh perfume for university under 700 EGP.`
- `I need a clean office perfume.`
- Simple Arabic fresh/woody recommendation.
- Simple similar-cheaper prompt after confirming it in the final demo run.

## Demo-Risky AI Prompts

- Long multi-turn memory tests.
- Contradictory prompts.
- Mixed Arabic-English negation.
- Gibberish or off-topic prompts.
- Petrichor/rain requests.
- External perfume lookup.
- Arbitrary committee stress prompts.

## Security Notes

- Service-account JSON and `.dev.vars` files were removed from the workspace during the repair pass.
- The removed keys must still be rotated/revoked in Google Cloud/Firebase because local deletion does not invalidate exposed credentials.
- Cloudflare secrets must be set with `wrangler secret put`; do not restore raw secret files into this repo.
- AI debug logs should remain disabled for the defense build.
- Worker CORS values should be confirmed against the exact deployed app/admin origins before the final demo.

## MVP Scope

Included:

- Auth and OTP reset.
- Catalog browsing/details.
- Cart/checkout/orders/cancel.
- Catalog-bounded AI recommendations and availability checks.
- Firestore-backed admin dashboard.
- Cloudflare Workers for AI, auth, and orders.
- Firebase/Firestore rules.

Out of scope:

- Real online payments.
- Public production launch hardening.
- Full ERP/admin operations.
- Guaranteed AI latency.
- Model training/fine-tuning.
- Automated data-retention jobs.

## Final Manual QA Required

Use `docs/defense-guide.md` for the manual checklist. Automated checks are green after the repair pass, but the project should not be considered final defense-ready until the manual checklist is completed on the same build/environment used for the committee demo.

## Current priority

- Bug fixes.
- Security cleanup.
- Test stabilization.
- Documentation.
- Small scoped feature work.

## Frozen scope

Do not introduce major architecture changes.
Do not add new backend services.
Do not change deployment strategy.
Do not change auth, database, Firebase, Cloudflare, or security behavior without explicit approval.

## Agent guidance

- Prefer small patches.
- Use targeted reading only.
- Ask before changing backend/cloud/security areas.
- Run the smallest relevant check after edits.
- Report what changed, what was tested, and what was not verified.
