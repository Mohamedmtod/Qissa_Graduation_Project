# AGENTS.md

This repository is a defensive/educational MVP mono-repo. Treat it as not production-ready.

## Primary goals

- Improve safety, correctness, and maintainability.
- Minimize token usage by reading only targeted files.
- Avoid broad refactors unless explicitly requested.
- Keep scope frozen: bug fixes, security cleanup, docs, and test stabilization.

## Repository areas

- `mobile_app/`: Flutter mobile app.
- `admin_dashboard/`: Flutter admin dashboard.
- `backend_and_cloud/`: Firebase, Cloudflare, backend code, rules, functions, and backend tests.
- `docs/`: project documentation and status notes.
- `testing_tools/`: local test helpers and validation utilities.

## Context rules

1. Start with this file.
2. Read targeted docs/status files first, especially:
   - `docs/current-project-status.md`
   - `docs/REPO_MAP.md` if present
3. Do not scan the whole repository by default.
4. Use targeted search only.
5. Identify the exact area and likely files before editing.
6. Prefer reading source/docs/configs/tests over generated files or build outputs.
7. Before modifying more than one file, explain the plan.
8. If the required change is unclear, or the task appears to require broad architectural changes, stop and ask for direction instead of exploring the whole repository.

## Sensitive files and data

Reading normal source code, docs, configs, and tests is allowed.

Never read, print, copy, summarize, modify, or infer secrets/private data unless explicitly requested by the user in the current message:

- `.env`
- `.env.*`
- `.dev.vars`
- service account files
- private keys
- API keys
- Firebase secrets
- Cloudflare tokens
- logs
- dumps
- database exports
- production data
- private user/customer data

Never add secrets to the repository. Use environment variables or secret managers instead.

## Sensitive zones

Treat these areas as high risk:

- `backend_and_cloud/`
- Firebase rules, indexes, functions, and project configuration
- Cloudflare workers and configuration
- auth
- billing/payment
- database access
- security rules
- permissions

For any sensitive-zone change:

1. Explain the risk.
2. List the files expected to change.
3. Make the smallest useful change.
4. Run the smallest relevant test/check.
5. Mention anything not verified.

## Risk levels

### Allowed automatically

The agent may do these without asking:

- Read/list/search normal source files, docs, configs, and tests.
- Inspect `git status`.
- Inspect `git diff`.
- Run safe checks:
  - Flutter analyze/test.
  - Node tests.
  - Firestore rules tests.
  - Formatting/lint checks.
- Make small, scoped edits after explaining the target and plan.

### Ask before

The agent must ask before:

- Installing packages.
- Adding, removing, or upgrading dependencies.
- Editing lockfiles.
- Editing more than 3 files.
- Changing project configuration.
- Changing auth, billing/payment, database access, Firebase, Cloudflare, security rules, or permissions.
- Running scripts that write generated output.
- Performing large refactors.

Do not add, remove, or upgrade dependencies unless the task explicitly requires it and the user approves.

### Require explicit same-message approval

Never run or perform these unless the user explicitly approves them in the current message.

Prior approval from earlier messages does not count.

- Deploy commands.
- Migration commands.
- Delete/clean/reset commands.
- Production commands.
- Commands touching secrets.
- Destructive database, Firebase, or Cloudflare operations.
- Reading or modifying `.env`, `.dev.vars`, keys, service accounts, logs, dumps, database exports, or private user data.
- `rm`
- `rm -rf`
- `git reset`
- `git clean`

## Git safety

Allowed without asking:

- `git status`
- `git diff`

Do not commit, push, pull, rebase, merge, reset, stash, checkout branches, or modify Git history unless explicitly requested.

## Tooling policy

- Codex is the primary agent for this repository.
- Antigravity or other agents should only handle small, isolated tasks.
- Do not let multiple agents edit overlapping files at the same time.
- If another agent has changed files, inspect `git status` and relevant diffs before editing.

## Editing rules

- Make the smallest useful change.
- Prefer bug fixes, security cleanup, docs, and test stabilization.
- Avoid broad architecture changes unless explicitly requested.
- Avoid introducing new dependencies unless necessary and approved.
- Do not change production-facing behavior without explaining the risk.
- For backend/cloud/security changes, explain risk before editing.

## Validation

After changes, run the smallest relevant check:

- Flutter app: analyze or targeted test in `mobile_app/`.
- Admin dashboard: analyze or targeted test in `admin_dashboard/`.
- Backend/cloud: targeted Node/Firebase/Firestore rules test.
- Docs-only changes do not require tests unless commands/config changed.

If tests cannot be run, explain why and list what was verified manually.

## Output expectations

Before edits:

- State the target area.
- List files likely to change.
- Explain risk if touching backend/cloud/security.

After edits:

- Summarize changed files.
- Summarize tests/checks run.
- Mention anything not verified.
