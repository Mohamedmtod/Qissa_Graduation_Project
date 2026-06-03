# Architecture

This is the consolidated architecture reference for the QISSAH project.

## 1. System Overview

QISSAH is a multi-part perfume commerce platform made of:

- a Flutter customer app
- an admin dashboard
- Cloudflare workers
- Firebase Auth and Firestore
- supporting test and documentation assets

The architecture is intentionally split so the customer app, admin dashboard, and backend services can evolve separately while still sharing one business model.

## 2. Main Layers

### Client Layer

- customer shopping, AI chat, cart, checkout, and profile flows
- admin operations, analytics, inventory, and content management

### Service Layer

- AI chat worker for structured recommendation responses
- auth worker for OTP recovery flows
- orders worker for stock-safe order handling

### Data Layer

- Firebase Auth for identity
- Firestore for products, users, orders, addresses, and support data
- security rules for access control

## 3. Major Capabilities

- catalog browsing and product discovery
- AI-assisted perfume recommendation
- order creation and tracking
- admin content and inventory management
- localization for Arabic and English
- worker-backed auth and backend safety checks

## 4. AI and Order Flow

### AI Flow

1. The user sends a perfume request.
2. The Flutter app prepares catalog context and preferences.
3. The AI worker returns a structured response plan.
4. The app validates the result locally.
5. Safe recommendations or fallback answers are rendered.

### Order Flow

1. The user checks out from the mobile app.
2. The backend worker validates the request.
3. Stock-safe writes are applied.
4. Firestore is updated with the order state.

## 5. Authentication Flow

1. Firebase Auth handles customer identity.
2. The auth worker handles OTP reset requests.
3. The app applies session and role-aware routing.
4. Firestore rules and backend checks enforce access control.

## 6. Reference Points

- `README.md` for project-level overview
- `project-map.md` for file navigation
- `current-project-status.md` for readiness
- `current-test-status.md` for verification state
- `capabilities/README.md` for functional capability summaries

