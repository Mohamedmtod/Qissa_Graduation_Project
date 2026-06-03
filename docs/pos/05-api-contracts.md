# POS Module — API Contracts

All endpoints: `perfume-pos-worker`. All requests: `Authorization: Bearer <firebase-token>`.

---

## Endpoints Summary

| Method | Path | Role | Purpose |
|---|---|---|---|
| GET | `/pos/products/search?q=` | cashier+ | Search sellable products |
| GET | `/pos/perfume-oils/search?q=` | cashier+ | Search oils for composite config |
| GET | `/pos/recipes/:recipeId` | cashier+ | Get composite recipe (no costPrice) |
| GET | `/pos/products/:pid/variants/:vid/recipe` | cashier+ | Get recipe by product+variant |
| POST | `/pos/cash-sessions/open` | cashier+ | Open a shift session |
| GET | `/pos/cash-sessions/current` | cashier+ | Get current open session |
| POST | `/pos/cash-sessions/:id/close` | cashier+ | Close session with counted cash |
| POST | `/pos/sales` | cashier+ | Create sale (main transaction) |
| GET | `/pos/sales/:id` | cashier+ | Get a single sale |
| GET | `/pos/sales` | admin+ | List sales with filters |
| GET | `/pos/reports/daily?date=` | admin+ | Daily totals |
| GET | `/pos/reports/cashier/:id` | admin+ | Per-cashier report |
| GET | `/pos/reports/profit` | admin+ | Gross profit report |
| GET | `/pos/reports/missing-cost` | admin+ | Missing costPrice report |

---

## POST /pos/cash-sessions/open

Request:
```json
{ "openingCash": 1000 }
```

Success (201):
```json
{ "sessionId": "cs_123", "status": "open", "openingCash": 1000, "openedAt": "..." }
```

Error:
```json
{ "error": "SESSION_ALREADY_OPEN", "existingSessionId": "cs_abc" }
```

---

## GET /pos/cash-sessions/current

Open session:
```json
{
  "sessionId": "cs_123", "status": "open",
  "openingCash": 1000, "expectedCash": 3500,
  "salesCount": 5, "grossSales": 12500,
  "paymentTotals": { "cash": 2500, "card": 10000, "instapay": 0, "wallet": 0 }
}
```

No session:
```json
{ "status": "no_open_session" }
```

---

## POST /pos/sales

Request:
```json
{
  "idempotencyKey": "device-user-uuid4",
  "cashSessionId": "cs_123",
  "paymentMethod": "cash",
  "items": [
    {
      "lineType": "simple",
      "productId": "bakhoor_001",
      "variantId": "default",
      "quantity": 2
    },
    {
      "lineType": "composite",
      "productId": "compound_perfume",
      "variantId": "compound_50ml",
      "recipeId": "recipe_50ml",
      "recipeVersion": 1,
      "quantity": 1,
      "selectedComponents": {
        "selected_perfume_oil": { "productId": "oil_sauvage", "variantId": "default" },
        "packaging": { "productId": "cloth_bag", "variantId": "default" }
      }
    }
  ]
}
```

Success (201):
```json
{
  "saleId": "sale_123",
  "saleCode": "POS-2026-000001",
  "status": "completed",
  "subtotal": 6100, "total": 6100,
  "paymentMethod": "cash",
  "profitIncomplete": false,
  "items": [
    { "lineType": "simple", "displayName": "Bakhoor Royal", "quantity": 2, "unitPrice": 350, "lineTotal": 700 },
    { "lineType": "composite", "displayName": "عطر تركيب 50ml - Sauvage Oil - كيس قماش", "quantity": 1, "unitPrice": 860, "lineTotal": 860 }
  ]
}
```

Stock conflict (409):
```json
{
  "error": "STOCK_CONFLICT",
  "conflicts": [{ "productId": "p1", "variantId": "v1", "requestedQuantity": 2, "availableStock": 0, "unitType": "piece" }]
}
```

Component stock conflict (409):
```json
{
  "error": "COMPONENT_STOCK_CONFLICT",
  "conflicts": [{ "productId": "oil_sauvage", "variantId": "default", "requiredQuantity": 15, "availableStock": 8, "unitType": "ml" }]
}
```

Recipe changed (409):
```json
{ "error": "RECIPE_CHANGED", "recipeId": "recipe_50ml", "currentVersion": 2, "sentVersion": 1 }
```

---

## POST /pos/cash-sessions/:id/close

Request:
```json
{ "countedCash": 5900, "notes": "تم تسليم الكاش" }
```

Response:
```json
{
  "sessionId": "cs_123", "status": "closed",
  "openingCash": 1000, "expectedCash": 6000,
  "countedCash": 5900, "cashDifference": -100,
  "salesCount": 8, "grossSales": 25000,
  "paymentTotals": { "cash": 5000, "card": 20000, "instapay": 0, "wallet": 0 }
}
```

---

## Error Code Reference

| Code | HTTP | Meaning |
|---|---|---|
| `STOCK_CONFLICT` | 409 | Simple/raw item has insufficient stock |
| `COMPONENT_STOCK_CONFLICT` | 409 | Composite component insufficient stock |
| `RECIPE_CHANGED` | 409 | Recipe version changed since cart was built |
| `NO_ACTIVE_RECIPE` | 400 | Composite product has no active recipe |
| `INVALID_COMPONENT_SELECTION` | 400 | Selected option not in allowed list |
| `NO_OPEN_SESSION` | 400 | No open session for this cashier |
| `SESSION_CLOSED` | 400 | Referenced session is already closed |
| `SESSION_ALREADY_OPEN` | 400 | Cashier already has open session |
| `INVALID_ROLE` | 403 | Role not allowed for this action |
| `PRODUCT_NOT_FOUND` | 400 | Product or variant not found |
| `PRODUCT_INACTIVE` | 400 | Product or variant is inactive |
| `TRANSACTION_FAILED` | 500 | Firestore transaction failed — nothing written |
