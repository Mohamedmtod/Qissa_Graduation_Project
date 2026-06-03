# POS Module — Agent Implementation Guide

> **Purpose**: Step-by-step execution guide for an AI agent implementing the POS module.
> Read this file first before touching any code.
> Read the reference docs in `docs/pos/` for full schema and contract details.

---

## Before You Start

### 1. Read these files first

```
docs/pos/README.md                   ← module index
docs/pos/01-overview-and-decisions.md
docs/pos/04-firestore-data-model.md  ← Firestore schema
docs/pos/05-api-contracts.md         ← HTTP API shapes
docs/pos/06-business-rules.md        ← transaction logic + scenarios
docs/pos/08-todo-and-phases.md       ← full checklist
```

### 2. Answer these questions by reading existing code before writing any code

| Question | Where to look |
|---|---|
| Are variants embedded array or subcollection? | Read a product document in Firestore or check the Orders Worker `src/orders/` |
| How does auth work in the existing workers? | `src/auth/require-user.js` in `perfume-orders-worker` |
| How are Firestore transactions done? | `src/firestore/transactions.js` in `perfume-orders-worker` |
| How does the Firestore REST client work? | `src/firestore/client.js` in `perfume-orders-worker` |
| How does the Admin Dashboard structure features? | `admin_dashboard/lib/features/admin/` |
| Does the Admin Dashboard use BLoC or Cubit? | Check `admin_dashboard/lib/features/admin/presentation/manager/` |

### 3. Do not touch these

```
perfume-orders-worker      ← do not modify
perfume-ai-chat-worker     ← do not touch
perfume-auth-worker        ← do not touch
mobile_app/                ← do not touch
Firebase security rules    ← ask before editing
```

---

## Repository Paths You Will Work In

```
backend_and_cloud/workers/perfume-pos-worker/     ← CREATE NEW
admin_dashboard/lib/features/pos/                 ← CREATE NEW
backend_and_cloud/firestore.rules                 ← EDIT (ask first)
docs/pos/                                         ← READ ONLY
```

---

## Existing Code You Can Copy/Adapt

| What | From |
|---|---|
| Firebase JWT verification | `perfume-orders-worker/src/auth/firebase-jwt.js` |
| Bearer token extraction | `perfume-orders-worker/src/auth/admin.js` → `getBearerToken` |
| Firestore REST client | `perfume-orders-worker/src/firestore/client.js` |
| Firestore transaction helpers | `perfume-orders-worker/src/firestore/transactions.js` |
| HTTP response helpers | `perfume-orders-worker/src/http/` |
| `wrangler.jsonc` shape | `perfume-orders-worker/wrangler.jsonc` |
| `package.json` dependencies | `perfume-orders-worker/package.json` (use same: `jose`, `firebase-admin`, `wrangler`) |

---

## Implementation Steps

Work through these steps in order.
Do not skip ahead. Do not start Flutter UI before the Worker is complete.

---

### STEP 1 — Inspect Existing Code (No edits yet)

**Goal**: Understand what you can reuse.

```
1. Read perfume-orders-worker/src/auth/firebase-jwt.js
2. Read perfume-orders-worker/src/auth/require-user.js
3. Read perfume-orders-worker/src/auth/admin.js
4. Read perfume-orders-worker/src/firestore/client.js
5. Read perfume-orders-worker/src/firestore/transactions.js
6. Read perfume-orders-worker/wrangler.jsonc
7. Read admin_dashboard/lib/features/admin/ folder structure
8. Find one existing Cubit in admin_dashboard to confirm the pattern
```

After step 1, note: are variants embedded array or subcollection? This affects step 4.

---

### STEP 2 — Create POS Worker Skeleton

**Files to create**:

```
backend_and_cloud/workers/perfume-pos-worker/
  wrangler.jsonc
  package.json
  src/
    index.js
    routes.js
    constants/index.js
    auth/
      verifyToken.js      ← copy from orders worker, adjust for POS roles
      requireRole.js      ← new: checks role claim (cashier/admin/owner)
    http/
      responses.js        ← copy from orders worker
      errors.js           ← copy from orders worker
    firestore/
      client.js           ← copy from orders worker
      codec.js            ← copy from orders worker
      transactions.js     ← copy from orders worker
    shared/
      money.js
      errors.js
      saleCode.js
      idempotency.js
      stock.js
      recipeResolver.js
```

**`wrangler.jsonc`** shape (adapt from orders worker):

```jsonc
{
  "name": "perfume-pos-worker",
  "main": "src/index.js",
  "compatibility_date": "2025-12-01",
  "workers_dev": true,
  "vars": {
    "ALLOWED_ORIGIN": "http://localhost:8080,http://localhost:3000",
    "FIREBASE_PROJECT_ID": ""
  }
}
```

**`requireRole.js`** logic:

```javascript
// Allowed roles for POS: cashier, admin, owner
// Read role from Firebase custom claims: claims.role
// If role not in allowed list → return 403 INVALID_ROLE
```

**`saleCode.js`** — generates `POS-YYYY-XXXXXX`:

```javascript
// Use Firestore counter or timestamp-based sequence
// Format: POS-2026-000001
// Simplest safe approach: use a Firestore counter document inside the transaction
```

**`idempotency.js`**:

```javascript
// checkIdempotency(env, key, cashierId) → returns existing saleId or null
// writeIdempotency(env, transaction, key, saleId, cashierId) → write inside transaction
```

**Verify skeleton**: `wrangler dev` should start without errors.

---

### STEP 3 — Cash Session APIs (no sale yet)

**Files to create**:

```
src/cashSessions/
  openCashSession.js
  getCurrentCashSession.js
  closeCashSession.js
```

**Routes**:

```
POST /pos/cash-sessions/open
GET  /pos/cash-sessions/current
POST /pos/cash-sessions/:id/close
```

**`openCashSession.js`** logic:

```
1. requireRole(cashier/admin/owner)
2. Query pos_cash_sessions where cashierId == uid AND status == "open"
3. If found → return SESSION_ALREADY_OPEN with existingSessionId
4. Create pos_cash_sessions document:
   cashierId, cashierNameSnapshot, status: "open"
   openingCash, expectedCash: same as openingCash
   salesCount: 0, grossSales: 0, netSales: 0
   paymentTotals: { cash:0, card:0, instapay:0, wallet:0 }
   openedAt: now
5. Return { sessionId, status: "open", openingCash, openedAt }
```

**`closeCashSession.js`** logic:

```
1. requireRole(cashier/admin/owner)
2. Read session by :id
3. Validate: session exists, status == "open"
4. Validate: cashierId matches uid (unless admin/owner)
5. cashDifference = countedCash - expectedCash
6. Update session: status: "closed", closedAt, countedCash, cashDifference, notes
7. Return session summary
```

**Test**: call `POST /pos/cash-sessions/open` with a valid Firebase token.

---

### STEP 4 — Product Search APIs

**Files to create**:

```
src/products/
  searchPosProducts.js
  searchPerfumeOils.js
```

**`searchPosProducts.js`** — `GET /pos/products/search?q=...`:

```
1. requireRole(cashier/admin/owner)
2. Query products where isActive == true AND isSellable == true
3. Filter by name/brand matching q (case-insensitive)
4. For each product: resolve variants (embedded or subcollection)
5. Return: productId, name, productType, brand, imageUrl, variants[]
   Per variant: variantId, label, price, salePrice, stock, unitType, isActive
   DO NOT return costPrice
```

**`searchPerfumeOils.js`** — `GET /pos/perfume-oils/search?q=...`:

```
1. requireRole(cashier/admin/owner)
2. Query products where productType == "raw_material" AND category == "perfume_oils"
   AND isActive == true AND isSellable == true
3. Filter by name matching q
4. Return: productId, variantId, name, stock, unitType
```

> **Important**: Check how variants are stored (embedded vs subcollection) and query accordingly.
> Match the pattern used in `perfume-orders-worker/src/orders/`.

---

### STEP 5 — Recipe APIs

**Files to create**:

```
src/recipes/
  getCompositeRecipe.js
  listCompositeRecipes.js
```

**`getCompositeRecipe.js`** — `GET /pos/recipes/:recipeId`:

```
1. requireRole(cashier/admin/owner)
2. Read composite_recipes/:recipeId
3. Validate: exists, isActive == true
4. Return recipe WITHOUT costPrice fields
```

Also support: `GET /pos/products/:productId/variants/:variantId/recipe`

```
1. Query composite_recipes where productId == :productId AND variantId == :variantId AND isActive == true
2. Return first result or 404
```

---

### STEP 6 — Create POS Sale (Core Transaction)

**File to create**: `src/sales/createPosSale.js`

**Route**: `POST /pos/sales`

This is the most important file. Follow this exact order inside the Firestore transaction:

```javascript
async function createPosSale(request, env) {

  // 1. Auth + role
  const auth = await requireRole(request, env, ["cashier", "admin", "owner"]);

  // 2. Parse body: { idempotencyKey, cashSessionId, paymentMethod, items }

  // 3. Check idempotency BEFORE starting transaction
  const existingSaleId = await checkIdempotency(env, idempotencyKey, auth.uid);
  if (existingSaleId) {
    // fetch and return existing sale
    return existingSaleResponse(env, existingSaleId);
  }

  // 4. Start Firestore transaction (use transactions.js from orders worker pattern)
  const txn = await beginTransaction(env);

  try {

    // 5. Read + validate cash session inside transaction
    const session = await readDocument(env, `pos_cash_sessions/${cashSessionId}`, txn);
    if (!session) throw posError("NO_OPEN_SESSION");
    if (session.status !== "open") throw posError("SESSION_CLOSED");
    if (session.cashierId !== auth.uid && !auth.isAdminOrOwner) throw posError("INVALID_ROLE");

    // 6. Process each item
    const writes = [];
    let subtotal = 0;
    let totalCost = 0;
    let profitIncomplete = false;
    const stockMovements = [];
    const saleItems = [];

    for (const item of items) {

      if (item.lineType === "simple") {
        // --- SIMPLE ITEM ---
        const { product, variant } = await readProductVariant(env, item.productId, item.variantId, txn);
        validateActive(product, variant);
        validateStock(variant, item.quantity);

        const finalUnitPrice = variant.salePrice ?? variant.price;
        const lineCost = variant.costPrice != null
          ? variant.costPrice * item.quantity
          : null;
        if (lineCost === null) profitIncomplete = true;

        subtotal += finalUnitPrice * item.quantity;
        if (lineCost !== null) totalCost += lineCost;

        // Decrement stock write
        writes.push(decrementStockWrite(item.productId, item.variantId, variant.stock, item.quantity));

        stockMovements.push({
          productId: item.productId, variantId: item.variantId,
          movementType: "pos_simple_sale",
          quantityChange: -item.quantity,
          unitType: variant.unitType,
          quantityBefore: variant.stock,
          quantityAfter: variant.stock - item.quantity,
        });

        saleItems.push(buildSimpleSaleItem(product, variant, item, finalUnitPrice, lineCost));

      } else if (item.lineType === "composite") {
        // --- COMPOSITE ITEM ---
        const recipe = await readDocument(env, `composite_recipes/${item.recipeId}`, txn);
        if (!recipe || !recipe.isActive) throw posError("NO_ACTIVE_RECIPE");
        if (recipe.recipeVersion !== item.recipeVersion) throw posError("RECIPE_CHANGED", { currentVersion: recipe.recipeVersion });

        const components = await resolveRecipeComponents(env, recipe, item.selectedComponents, txn);
        // resolveRecipeComponents: returns list of { productId, variantId, quantity, unitType, costPrice, stock }

        for (const comp of components) {
          validateStock(comp, comp.quantity * item.quantity);
          writes.push(decrementStockWrite(comp.productId, comp.variantId, comp.stock, comp.quantity * item.quantity));
          if (comp.costPrice === null) profitIncomplete = true;
          else totalCost += comp.costPrice * comp.quantity * item.quantity;

          stockMovements.push({
            productId: comp.productId, variantId: comp.variantId,
            movementType: "pos_composite_component",
            quantityChange: -(comp.quantity * item.quantity),
            unitType: comp.unitType,
            quantityBefore: comp.stock,
            quantityAfter: comp.stock - (comp.quantity * item.quantity),
          });
        }

        const { product, variant } = await readProductVariant(env, item.productId, item.variantId, txn);
        const priceDelta = components
          .filter(c => c.priceDelta != null)
          .reduce((sum, c) => sum + c.priceDelta, 0);
        const basePrice = recipe.sellingPrice ?? variant.price;
        const finalUnitPrice = (basePrice + priceDelta) * item.quantity;

        subtotal += finalUnitPrice;
        saleItems.push(buildCompositeSaleItem(product, variant, recipe, item, components, finalUnitPrice, profitIncomplete));
      }
    }

    // 7. Generate sale ID and sale code
    const saleId = crypto.randomUUID();
    const saleCode = await generateSaleCode(env, writes); // increments counter inside transaction

    // 8. Build pos_sales write
    const total = subtotal; // discountTotal = 0 in Phase 1
    writes.push(createSaleWrite(saleId, { cashierId: auth.uid, cashSessionId, paymentMethod, subtotal, total, saleCode, profitIncomplete, totalCost: profitIncomplete ? null : totalCost }));

    // 9. Build sale item writes
    for (const item of saleItems) {
      writes.push(createSaleItemWrite(saleId, item));
    }

    // 10. Build payment write
    writes.push(createPaymentWrite(saleId, cashSessionId, auth.uid, paymentMethod, total));

    // 11. Build stock movement writes
    for (const mv of stockMovements) {
      writes.push(createStockMovementWrite(saleId, mv));
    }

    // 12. Update cash session totals
    writes.push(updateSessionWrite(cashSessionId, session, paymentMethod, total, totalCost, profitIncomplete));

    // 13. Write idempotency record
    writes.push(createIdempotencyWrite(idempotencyKey, saleId, auth.uid));

    // 14. Commit
    await commitTransaction(env, txn, writes);

    // 15. Return invoice
    return invoiceResponse(saleId, saleCode, saleItems, total, subtotal, paymentMethod, totalCost, profitIncomplete);

  } catch (error) {
    await rollbackTransaction(env, txn);
    throw error;
  }
}
```

**`shared/recipeResolver.js`** — called inside the transaction:

```
resolveRecipeComponents(env, recipe, selectedComponents, txn):
  for each component in recipe.components:

    if componentType == "fixed_product":
      productId = component.productId
      variantId = component.variantId
      read product+variant from Firestore inside txn

    if componentType == "selected_perfume_oil":
      productId = selectedComponents.selected_perfume_oil.productId
      variantId = selectedComponents.selected_perfume_oil.variantId
      read product inside txn, validate category == "perfume_oils"

    if componentType == "selectable_product":
      selected = selectedComponents[component.label]
      if not selected and component.optional: skip
      if not selected and not optional: throw INVALID_COMPONENT_SELECTION
      validate selected option is in component.options
      priceDelta = option.priceDelta

    quantity = component.quantity
    return { productId, variantId, quantity, stock, costPrice, unitType, priceDelta }
```

**Test**: call `POST /pos/sales` with a simple item. Verify:
- `pos_sales` document created
- `pos_sales/{id}/items` document created
- `pos_payments` document created
- `stock_movements` document created
- variant stock decremented
- `pos_cash_sessions` totals updated

---

### STEP 7 — Remaining Sale APIs

**Files to create**:

```
src/sales/getPosSale.js      ← GET /pos/sales/:id
src/sales/listPosSales.js    ← GET /pos/sales
```

---

### STEP 8 — Reports APIs

**Files to create** (implement after MVP 1 Flutter is working):

```
src/reports/getDailyPosReport.js
src/reports/getCashierReport.js
src/reports/getProfitReport.js
src/reports/getMissingCostReport.js
```

---

### STEP 9 — Flutter POS Feature (MVP 1: Simple Items)

**Target folder**: `admin_dashboard/lib/features/pos/`

Follow Clean Architecture exactly as the existing `admin` feature.

**Order of implementation**:

```
1. Domain layer first:
   entities/: PosProduct, PosVariant, PosCartItem, PosSale, CashSession, PaymentMethod
   repositories/pos_repository.dart (abstract)
   usecases/: SearchPosProducts, AddItemToCart, CompletePosale, OpenCashSession, etc.

2. Data layer:
   models/: PosProductModel, PosVariantModel, CreatePosSaleRequestModel, etc.
   datasources/pos_remote_datasource.dart (HTTP calls to POS Worker)
   datasources/pos_local_datasource.dart (cart persistence, idempotency key storage)
   repositories/pos_repository_impl.dart

3. State (Cubit) layer:
   CashSessionCubit + CashSessionState
   PosProductSearchCubit + PosProductSearchState
   PosCubit + PosState (with PosSubmitStatus enum)

4. Presentation layer:
   Screens: CashSessionScreen, PosScreen, SaleInvoiceScreen, CloseSessionScreen
   Widgets: (see list in 03-flutter-structure.md)
```

**`PosSubmitStatus` enum**:

```dart
enum PosSubmitStatus {
  idle, submitting, success,
  stockConflict, componentStockConflict, recipeChanged,
  offlineBlocked, unknownResult, failure
}
```

**`PosState`** — must include:

```dart
class PosState {
  final List<PosCartItem> cartItems;
  final PaymentMethod? selectedPaymentMethod;
  final int displaySubtotal;
  final bool isOnline;
  final PosSubmitStatus submitStatus;
  final String currentIdempotencyKey;  // NEVER change this during unknownResult
  final List<StockConflict> stockConflicts;
  final String? errorMessage;
}
```

**Idempotency key rule** (critical):

```dart
// On first attempt: generate UUID → store in state
// On unknownResult retry: send the SAME UUID
// On success/failure: generate NEW UUID for next sale
// NEVER generate new UUID while submitStatus == unknownResult
```

**Connectivity**:

```dart
// Add connectivity_plus listener in PosCubit
// When offline: submitStatus = offlineBlocked
// When back online: if was offlineBlocked → set to idle
// Complete Sale button enabled only when:
//   cartItems.isNotEmpty &&
//   selectedPaymentMethod != null &&
//   isOnline &&
//   submitStatus != submitting &&
//   submitStatus != offlineBlocked
```

**Add POS route to router**:

```
Read admin_dashboard/lib/bootstrap.dart or main routing file
Add /pos route pointing to CashSessionScreen (entry point)
Add POS entry to sidebar navigation
```

---

### STEP 10 — Flutter MVP 2: Composite Items

Only start after MVP 1 is working end-to-end.

**Additional files**:

```
domain/entities/CompositeRecipe, RecipeComponent, SelectedComponent
presentation/cubit/CompositeConfigCubit + CompositeConfigState
presentation/widgets/CompositeConfigDialog
presentation/widgets/PerfumeOilSelector
presentation/widgets/ComponentOptionSelector
presentation/widgets/RecipeChangedDialog
```

**`CompositeConfigCubit` flow**:

```
loadRecipe(productId, variantId)
  → GET /pos/products/:productId/variants/:variantId/recipe
  → emit recipeLoaded

searchOils(query)
  → GET /pos/perfume-oils/search?q=query
  → emit oilResultsLoaded

selectOil(productId, variantId)
  → update currentSelections, validate → emit recipeLoaded

selectOption(componentLabel, option)
  → update currentSelections → emit recipeLoaded

confirmSelection()
  → validate all required components selected
  → build PosCartItem with lineType = "composite", selectedComponents, recipeVersion
  → emit readyToAdd
  → caller: PosCubit.addCompositeItem(cartItem)
```

**Composite `PosCartItem`**:

```dart
PosCartItem(
  lineType: "composite",
  productId: ...,
  variantId: ...,
  recipeId: ...,
  recipeVersion: recipe.recipeVersion,   // sent to Worker for version check
  selectedComponents: { ... },
  quantity: 1,
  displayName: "عطر تركيب 50ml - Sauvage Oil - كيس قماش",
  displayUnitPrice: basePrice + priceDelta,
)
```

---

### STEP 11 — Firestore Security Rules

**Ask before editing.**

After getting approval, add rules for the new collections:

```
pos_sales         → authenticated admin/owner/cashier to read; only POS Worker to write
pos_payments      → same
pos_cash_sessions → same
stock_movements   → admin/owner to read; only Workers to write
composite_recipes → admin/owner to read/write; cashier to read only
pos_idempotency   → only Workers to read/write
```

---

### STEP 12 — Reports (After MVP 1 Is Running)

Implement report endpoints and UI after the core sale flow is validated.

---

## Common Mistakes to Avoid

```
1. DO NOT store price in Flutter cart as source of truth — Worker reads from Firestore
2. DO NOT generate a new idempotencyKey when submitStatus == unknownResult
3. DO NOT split a sale across multiple Firestore operations outside a transaction
4. DO NOT add costPrice to any API response visible to the cashier
5. DO NOT add POS logic to perfume-orders-worker
6. DO NOT start Flutter UI before testing the Worker transaction manually
7. DO NOT allow Complete Sale when offline
8. DO NOT skip stock_movements — one per item (simple) or one per component (composite)
```

---

## Testing Checklist Per Step

### After STEP 2 (Worker skeleton)
```
[ ] wrangler dev starts with no errors
[ ] GET / returns 200 or 404 (any response)
[ ] Valid Firebase token → auth succeeds
[ ] Invalid token → 401
[ ] Wrong role → 403
```

### After STEP 3 (Cash sessions)
```
[ ] POST /pos/cash-sessions/open creates session document in Firestore
[ ] GET /pos/cash-sessions/current returns { status: "no_open_session" } when none
[ ] GET /pos/cash-sessions/current returns session when open
[ ] Second POST open → SESSION_ALREADY_OPEN error
[ ] POST close → session marked closed with correct cashDifference
```

### After STEP 6 (Create sale)
```
[ ] Simple sale: pos_sales doc created with correct fields
[ ] Simple sale: pos_sales/{id}/items created
[ ] Simple sale: variant stock decremented correctly
[ ] Simple sale: pos_cash_sessions.salesCount += 1
[ ] Simple sale: pos_cash_sessions.expectedCash += total (if cash payment)
[ ] Simple sale: stock_movements document created
[ ] Duplicate idempotencyKey: returns same invoice, stock NOT decremented again
[ ] No session: NO_OPEN_SESSION error
[ ] Stock = 0: STOCK_CONFLICT error
[ ] Composite sale: all components decremented
[ ] Composite sale: one stock_movement per component
[ ] Wrong recipeVersion: RECIPE_CHANGED error
[ ] Missing component selection: INVALID_COMPONENT_SELECTION error
```

### After STEP 9 (Flutter MVP 1)
```
[ ] No session → CashSessionScreen shown
[ ] Open session → PosScreen shown with session header
[ ] Search returns products
[ ] Add simple item to cart
[ ] Cart total updates correctly
[ ] Complete Sale disabled when offline
[ ] Complete Sale disabled when cart empty
[ ] Complete Sale succeeds → SaleSuccessDialog shown, cart cleared
[ ] Stock conflict → StockConflictDialog shown
[ ] Network failure after submit → unknownResult → retry with same key → success
```

---

## Reference Files

| Topic | File |
|---|---|
| Full data model | `docs/pos/04-firestore-data-model.md` |
| API shapes | `docs/pos/05-api-contracts.md` |
| Transaction logic | `docs/pos/06-business-rules.md` |
| Flutter states | `docs/pos/07-flutter-state-management.md` |
| Full checklist | `docs/pos/08-todo-and-phases.md` |
| Existing auth | `perfume-orders-worker/src/auth/` |
| Existing Firestore client | `perfume-orders-worker/src/firestore/` |
