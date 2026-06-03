# Perfume Orders Worker

This worker is the backend command layer for order creation, cancellation, status transitions, and stock-safe mutations.

## What It Does

- Accepts authenticated order requests from the Flutter app.
- Validates payloads and idempotency keys.
- Applies atomic stock deduction and restock logic.
- Enforces the allowed order status state machine.
- Rejects invalid transitions and unauthorized actions.
- Supports admin-only order state updates.

## Core Contract

See [API_CONTRACT.md](API_CONTRACT.md) for the exact request and response contract, allowed statuses, and transition rules.

## Current Status Flow

- `pending`
- `order_processing`
- `out_for_delivery`
- `delivered`
- `cancelled`

Allowed transitions:

- `pending -> order_processing`
- `pending -> cancelled`
- `order_processing -> out_for_delivery`
- `order_processing -> cancelled`
- `out_for_delivery -> delivered`

## How It Runs

Local run:

```bash
npm install
npx wrangler dev
```

Useful checks:

```bash
npm test
```

Manual / production actions (require explicit approval):

```bash
npm run deploy
```

## Security Notes

- All order mutations require a Firebase ID token.
- Admin transitions require admin privileges in addition to authentication.
- The worker must remain the only write path for sensitive order and stock mutations.

## Notes For Review

- This worker is intentionally kept separate from the client app.
- The Flutter app should call the worker instead of writing orders directly to Firestore.
