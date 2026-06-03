# Backend And Cloud Capabilities

The backend and cloud layer provides the secure runtime foundation for the whole platform.

## What The Backend Can Do

- Authenticate users through Firebase Auth.
- Store and query business data in Firestore.
- Enforce security rules and access control.
- Process orders through Cloudflare Workers.
- Handle AI chat requests through the AI worker.
- Support auth-related worker flows where needed.
- Keep order and availability flows consistent with the catalog.
- Provide backend hooks for analytics, reporting, and operational automation.
- Support local development and emulator-based checks.

## What Makes It Important

- It keeps sensitive logic off the client.
- It separates customer actions from server-side business rules.
- It reduces the chance of stock or order inconsistency.
- It supports a more realistic graduation-project architecture.
