# API Contract (H2-H4)

This document defines the order API contract and allowed status transitions.

## Base

- Worker base URL: `https://<worker-subdomain>.workers.dev`
- Content type: `application/json`
- Authentication: Firebase ID token via `Authorization: Bearer <token>`

## Statuses

- `pending`
- `order_processing`
- `out_for_delivery`
- `delivered`
- `cancelled`

## Allowed Transitions

- `pending -> order_processing`
- `pending -> cancelled`
- `order_processing -> out_for_delivery`
- `order_processing -> cancelled`
- `out_for_delivery -> delivered`

No other transitions are allowed.

## Endpoints

### `POST /orders`

Create order request after validation and stock deduction (implementation in next phase).

Auth:

- Requires valid user token (`401` if missing/invalid).

Request body (minimum contract):

```json
{
  "idempotencyKey": "uuid-v4",
  "items": [
    { "productId": "p1", "quantity": 2 }
  ],
  "orderSource": "app",
  "address": "Cairo, ...",
  "phone": "01xxxxxxxxx",
  "paymentMethod": "Cash on Delivery",
  "notes": "optional"
}
```

Idempotency hash contract:

- `shippingGovernorate` and `clientShippingFee` are advisory metadata.
- They are normalized and may be persisted, but they do not participate in the idempotency payload hash.
- Identity fields such as `items`, `address`, and `shippingZoneCode` do participate.
- This behavior is covered by `tests/idempotency-hash-contract.test.js`.

`orderSource` values:

- `app` (default)
- `ai_chat` (when checkout started from AI chat recommendations)

Expected success message for UI:

- `Order placed successfully, Awaiting store processing`

Initial status:

- `pending`

Response body includes the internal `orderId` and the customer-facing `orderCode`:

```json
{
  "ok": true,
  "message": "Order placed successfully, Awaiting store processing",
  "orderId": "uuid-v4",
  "orderCode": "QA-8K3D2Q7A",
  "status": "pending",
  "stockDeducted": true,
  "idempotent": false
}
```

### `POST /orders/:id/cancel`

Customer cancellation endpoint.

Auth:

- Requires valid user token (`401` if missing/invalid).

Rule:

- Customer can cancel only if current status is `pending`.

If order was already stock-deducted, stock must be restored atomically.

### `POST /admin/orders/:id/status`

Admin-only endpoint to move order through state machine.

Auth:

- Requires valid user token.
- Requires admin role/allowlist (`403` if authenticated but not admin).

Request body:

```json
{
  "fromStatus": "pending",
  "toStatus": "order_processing"
}
```

Validation:

- transition must be in allowed transition list.

### `GET /orders/my`

Return customer orders (owned by authenticated user).

Auth:

- Requires valid user token (`401` if missing/invalid).

## Error Codes (Contract)

- `400` invalid payload
- `401` unauthenticated (implemented at auth middleware)
- `403` unauthorized (implemented at admin endpoint)
- `409` invalid state transition / illegal cancel action
