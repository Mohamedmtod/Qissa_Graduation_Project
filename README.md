# QISSAH Graduation Project

QISSAH is a graduation project for a perfume commerce ecosystem. It combines a Flutter customer app, an admin dashboard, backend workers, Firebase services, and a documented AI-assisted shopping flow.

## Repository Layout

```text
Qissa_Graduation_Project/
|-- mobile_app/             # Customer Flutter app
|-- admin_dashboard/        # Admin Flutter app
|-- backend_and_cloud/      # Firebase and Cloudflare backend pieces
|-- ai_and_analytics_tools/ # AI and analytics support scripts
|-- docs/                   # Canonical project documentation
`-- testing_tools/          # Test runners and utility scripts
```

## What The Project Covers

- Customer browsing, cart, checkout, and order tracking
- AI-assisted perfume recommendations, availability flows, product-context answers, and guarded catalog search
- Admin operations, reporting, and content management
- Firebase auth and Firestore-backed persistence
- Automated tests and runnable local scripts

## Current AI Chat Status

AI Chat PR8 is documented as a conservative Production MVP Candidate. The latest post-RC fixes keep production defaults safe while improving staging behavior:

- clear product-context questions answer locally without new recommendation cards
- ambiguous visible product references ask which product the user means
- direct catalog queries such as `أغلى عطر عندك` resolve locally before interpretation-worker escalation
- suitability now uses deterministic scoring/penalties for normal context fit
- visible recommendation reasons hide internal suitability codes

## Main Entry Points

- `mobile_app/lib/main.dart`
- `admin_dashboard/lib/main.dart`
- `testing_tools/tool/test_main_app.ps1`
- `testing_tools/tool/test_admin_dashboard.ps1`
- `testing_tools/tool/test_full.ps1`

## Documentation

Start here:

- `docs/current-project-status.md`
- `docs/current-test-status.md`
- `docs/ai_chat_pr8_release_candidate.md`
- `docs/capabilities/ai-chat-capabilities.md`
- `docs/README.md`
- `docs/project-map.md`
- `backend_and_cloud/workers/perfume-orders-worker/README.md`

## Notes For Review

- The structure is intentionally preserved.
- Historical documents stay in `docs/` for traceability, but current status always comes from the status files above.
- Production PR8 flags remain conservative/off until staging UI smoke and rollout approval.
