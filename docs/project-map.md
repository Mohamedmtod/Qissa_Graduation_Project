# Project Map

Use this document for fast navigation. For current readiness and test results, start with `current-project-status.md` and `current-test-status.md`.

## Repository Areas

| Path | Purpose |
| --- | --- |
| `mobile_app/` | Customer Flutter application. |
| `admin_dashboard/` | Admin Flutter application. |
| `backend_and_cloud/` | Backend and cloud integration assets. |
| `ai_and_analytics_tools/` | AI and analytics support scripts. |
| `testing_tools/` | PowerShell and Dart runners for tests and local checks. |
| `docs/` | Canonical project documentation. |

## Mobile App

Main app source:

- `mobile_app/lib/main.dart`
- `mobile_app/lib/core/`
- `mobile_app/lib/features/`
- `mobile_app/lib/widgets/`

Primary feature groups:

- `ai_chat`
- `auth`
- `cart`
- `orders`
- `products`
- `profile`
- `recommendations`
- `wishlist`

## Admin Dashboard

Admin source:

- `admin_dashboard/lib/main.dart`
- `admin_dashboard/lib/main_dev.dart`
- `admin_dashboard/lib/main_prod.dart`
- `admin_dashboard/lib/main_staging.dart`
- `admin_dashboard/lib/bootstrap.dart`
- `admin_dashboard/lib/core/`
- `admin_dashboard/lib/features/admin/`

## Testing Tools

Scripts in `testing_tools/tool/` cover:

- main app checks
- admin dashboard checks
- full-project test runs
- local stack startup
- AI chat live runners and result decoding

## Documentation Entry Points

Start here:

- `docs/README.md`
- `docs/current-project-status.md`
- `docs/current-test-status.md`
- `docs/architecture.md`
- `docs/ai-runtime-guide.md`

Useful supporting docs:

- `docs/localization-guide.md`
- `backend_and_cloud/workers/perfume-orders-worker/README.md`
- `backend_and_cloud/workers/perfume-orders-worker/API_CONTRACT.md`

## Navigation Rule

- Update app behavior in `mobile_app/`.
- Update admin behavior in `admin_dashboard/`.
- Update shared status or history in `docs/`.
- Keep working files, logs, and scratch outputs out of the review path.
