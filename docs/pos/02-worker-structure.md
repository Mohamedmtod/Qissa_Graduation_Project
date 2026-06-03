# POS Module — Cloudflare Worker Structure

## Folder Layout

```
backend_and_cloud/workers/perfume-pos-worker/
  wrangler.jsonc
  package.json
  src/
    index.js
    routes.js
    constants/index.js
    auth/
      verifyToken.js
      requireRole.js
    http/
      responses.js
      errors.js
    firestore/
      client.js
      codec.js
      transactions.js
    products/
      searchPosProducts.js
      searchPerfumeOils.js
    recipes/
      getCompositeRecipe.js
      listCompositeRecipes.js
    sales/
      createPosSale.js
      getPosSale.js
      listPosSales.js
    cashSessions/
      openCashSession.js
      getCurrentCashSession.js
      closeCashSession.js
    reports/
      getDailyPosReport.js
      getCashierReport.js
      getProfitReport.js
      getMissingCostReport.js
    shared/
      money.js
      errors.js
      saleCode.js
      idempotency.js
      stock.js
      recipeResolver.js
```

---

## Reuse from Existing Orders Worker

Copy these files (adapt, do not import cross-worker):

| Copy from `perfume-orders-worker/src/` | To `perfume-pos-worker/src/` |
|---|---|
| `auth/firebase-jwt.js` | `auth/verifyToken.js` |
| `auth/admin.js` | `auth/requireRole.js` (extend with POS roles) |
| `firestore/client.js` | `firestore/client.js` |
| `firestore/codec.js` | `firestore/codec.js` |
| `firestore/transactions.js` | `firestore/transactions.js` |
| `http/responses.js` | `http/responses.js` |
| `http/errors.js` | `http/errors.js` |

---

## `requireRole.js`

Extends the existing auth pattern to support POS-specific roles:

```javascript
// Roles: cashier, admin, owner
// Read from Firebase custom claim: claims.role
// cashier: can sell, open/close own session
// admin: can do everything cashier does + view all sessions + reports
// owner: same as admin + access to profit data
```

---

## Error Codes (shared/errors.js)

| Code | HTTP | Meaning |
|---|---|---|
| `STOCK_CONFLICT` | 409 | Simple/raw item insufficient stock |
| `COMPONENT_STOCK_CONFLICT` | 409 | Composite component insufficient stock |
| `RECIPE_CHANGED` | 409 | Recipe version mismatch |
| `NO_ACTIVE_RECIPE` | 400 | Composite product has no active recipe |
| `INVALID_COMPONENT_SELECTION` | 400 | Selected option not in allowed list |
| `NO_OPEN_SESSION` | 400 | No open cash session |
| `SESSION_CLOSED` | 400 | Referenced session is closed |
| `SESSION_ALREADY_OPEN` | 400 | Cashier already has open session |
| `INVALID_ROLE` | 403 | Role not permitted for this action |
| `PRODUCT_NOT_FOUND` | 400 | Product or variant not found |
| `PRODUCT_INACTIVE` | 400 | Product or variant inactive |
| `TRANSACTION_FAILED` | 500 | Firestore transaction failed — nothing written |

---

## Key Files: Responsibilities

### `shared/recipeResolver.js`

Called inside the Firestore transaction. Resolves a composite cart item into concrete component depletions:

```
resolveRecipeComponents(env, recipe, selectedComponents, txn):
  for each component in recipe.components:
    fixed_product      → use component.productId/variantId
    selected_perfume_oil → use selectedComponents.selected_perfume_oil, validate category
    selectable_product → use selection or default, validate options, apply priceDelta
    optional + none selected → skip
  multiply quantity by item.quantity
  return: [{ productId, variantId, quantity, stock, costPrice, unitType, priceDelta }]
```

### `shared/saleCode.js`

Generates `POS-YYYY-XXXXXX`.
Use a Firestore counter document inside the transaction to guarantee uniqueness.

### `shared/idempotency.js`

```
checkIdempotency(env, key, cashierId) → saleId | null
writeIdempotency(env, writes, key, saleId, cashierId) → adds write to batch
```

### `shared/stock.js`

```
validateStock(variant, requiredQty) → throws STOCK_CONFLICT if variant.stock < requiredQty
decrementStockWrite(productId, variantId, currentStock, qty) → Firestore update write object
```

---

## Notes

- Do not add POS routes to `perfume-orders-worker`.
- All writes for a single sale must be inside one Firestore transaction.
- Never return `costPrice` to the cashier in any search or recipe endpoint.
