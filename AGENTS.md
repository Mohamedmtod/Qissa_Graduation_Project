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
- `ai_and_analytics_tools/`: AI and analytics scripts.

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
- Editing `.gitignore`.
- Running any `git add`, `git commit`, or `git push`.

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
- `Remove-Item -Recurse -Force .git` — this deletes ALL git history. Only run when user explicitly says so.
- `git reset`
- `git clean`
- `git push --force` — this overwrites GitHub history. Requires explicit approval every time.
- `Copy-Item` backup commands that copy large directories.

## Git safety

### Allowed without asking:

- `git status`
- `git diff`
- `git log --oneline -n 10` (read-only, limited)
- `git check-ignore -v <file>` (read-only check)

### Must ask before:

- `git add`
- `git commit`
- `git push` (any form)
- `git pull`
- `git merge`
- `git rebase`
- `git stash`
- `git checkout` (branch changes)

### Require explicit same-message approval:

- `git push --force` or `git push -f` — overwrites remote history permanently.
- `Remove-Item -Recurse -Force .git` — deletes local git history permanently.
- `git reset --hard`
- `git clean -fd`

## Repository state after clean push

After the clean Git push completed on 2026-06-03, this repository uses a **fresh single-commit history** on `main`.

### What IS tracked (must stay tracked):

```
README.md
AGENTS.md
codemagic.yaml
.gitignore
mobile_app/
  pubspec.yaml
  pubspec.lock
  android/         (build configs, manifests — NOT .gradle/ or .kotlin/)
  ios/             (Runner/, project files — NOT Pods/)
  web/
  lib/
  test/
  integration_test/
  l10n.yaml
  analysis_options.yaml
admin_dashboard/
  pubspec.yaml
  pubspec.lock
  android/
  ios/
  web/
  lib/
  test/
  analysis_options.yaml
backend_and_cloud/
  functions/
    package.json
    package-lock.json
    (source files)
  rules/
    firebase.json
    firestore.rules
    firestore.indexes.json
  workers/*/
    package.json
    package-lock.json
    wrangler.toml or wrangler.jsonc
    src/
    test/
docs/
testing_tools/
  (scripts and helpers — NOT *.log or local data files)
ai_and_analytics_tools/
```

### What must NEVER be committed:

```
.wrangler/                          # Wrangler local state — NEVER commit
**/.wrangler/                       # Nested wrangler state
mobile_app/build/                   # Flutter build output
admin_dashboard/build/              # Flutter build output
mobile_app/.dart_tool/              # Dart tool cache
admin_dashboard/.dart_tool/         # Dart tool cache
mobile_app/.metadata                # Flutter IDE metadata
mobile_app/devtools_options.yaml    # Dev-only Flutter tool
admin_dashboard/devtools_options.yaml
**/android/.gradle/                 # Gradle local cache
**/android/.kotlin/                 # Kotlin local cache
**/ios/Pods/                        # CocoaPods local cache
**/node_modules/                    # Node dependencies
test_artifacts/                     # Test run outputs
coverage/                           # Coverage reports
*.log                               # Any log files
firebase-debug.log
firestore-debug.log
.env                                # Secrets
.env.*                              # Secrets
.dev.vars                           # Cloudflare secrets
serviceAccount*.json                # Service account keys
service-account*.json               # Service account keys
*.pem                               # Private keys
*.key                               # Private keys
```

If any of these appears in `git status` as untracked or staged, **stop and update `.gitignore` before committing**.

## Adding new features or areas

If a new feature, worker, package, or service area is added to the project, the agent must:

1. **Check `.gitignore`** to ensure any generated/cache directories for the new area are covered.
2. **Do NOT commit** build outputs, lock caches, or secrets from the new area.
3. For new Cloudflare workers: ensure `.wrangler/` inside the worker directory is in `.gitignore`.
4. For new Flutter packages: ensure `.dart_tool/`, `build/`, `.metadata` are covered.
5. For new Node packages: ensure `node_modules/` is covered.
6. For new Firebase services: ensure debug logs and emulator artifacts are covered.
7. After adding new files, run `git status --short` and review all `??` (untracked) entries before `git add .`.

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

## Pre-commit checklist (run before any `git add .`)

Before staging files, always verify:

```powershell
# Check that these are ignored (each should return a rule name, not blank):
git check-ignore -v .wrangler
git check-ignore -v backend_and_cloud/firebase-debug.log
git check-ignore -v mobile_app/devtools_options.yaml
git check-ignore -v mobile_app/.metadata

# Check git status for anything suspicious:
git status --short
```

If any of the above does NOT return a rule, add the pattern to `.gitignore` before continuing.
