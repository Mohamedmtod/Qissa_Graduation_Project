# Perfume Admin Dashboard

Admin dashboard for the `perfume_app` ecosystem, built with Flutter (Web-first).

## Project Location

- App directory: `perfume_app_admin_dashboard/`
- CI workflow file (repo root): `.github/workflows/admin_dashboard_ci.yml`

## Documentation

- [Architecture](docs/architecture.md)
- [Quality Gate](docs/quality-gate.md)
- [Integration Decisions](docs/integration_decisions.md)
- [Admin Security Matrix](docs/admin_security_matrix.md)
- [Shared Schema Contracts](lib/shared_schema_contracts.md)

## Run Locally

From inside `perfume_app_admin_dashboard`:

```bash
flutter pub get
flutter run -d chrome --target lib/main_dev.dart
```

Other flavors:

```bash
flutter run -d chrome --target lib/main_staging.dart
flutter run -d chrome --target lib/main_prod.dart
```
