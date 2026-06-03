# POS Module — TODO and Phases

## Phase 0 — Decisions (Resolve Before Writing Code)

```
[ ] Confirm: variants embedded array or subcollection in Firestore?
[ ] Confirm: liquid raw material stock tracked in ml?
[ ] Confirm: can cashier sell raw material in arbitrary ml quantity, or fixed variant sizes only?
[ ] Confirm: composite selling price from recipe.sellingPrice or variant.price?
[ ] Confirm: packaging optional or required per recipe?
[ ] Decide: costPrice for each existing variant
[ ] Decide: isSellable flag for each raw material
[ ] Decide: unitType for each product
[ ] Confirm: Admin Dashboard state management is Cubit (assumed yes)
[ ] Confirm: does Orders Worker have reusable auth middleware?
```

---

## Phase 1 — Product Model Upgrade

```
[ ] Add productType to products
[ ] Add isSellable to products
[ ] Add unitType to products and variants
[ ] Add costPrice to all variants
[ ] Update Firestore security rules for new fields
[ ] Update Admin product form (add productType, unitType, costPrice, isSellable)
[ ] Add productType filter in Admin product list
[ ] Add missing costPrice warning in Admin
```

---

## Phase 2 — Recipe System

```
[ ] Create composite_recipes Firestore collection
[ ] Add recipeVersion (increment on every edit)
[ ] Implement component types: fixed_product, selected_perfume_oil, selectable_product
[ ] Build Admin UI to create and edit recipes
[ ] Build Admin recipe preview: components + estimated cost + profit margin
[ ] Validate: composite product requires active recipe
[ ] Add Firestore rules for composite_recipes
```

---

## Phase 3 — POS Worker

```
[ ] Create perfume-pos-worker (wrangler.jsonc, package.json)
[ ] Copy and adapt auth from perfume-orders-worker
[ ] Add requireRole (cashier/admin/owner)
[ ] Implement cash sessions: open, current, close
[ ] Implement product search (simple + sellable raw materials + composite)
[ ] Implement perfume oil search
[ ] Implement recipe fetch endpoints
[ ] Implement POST /pos/sales (core transaction):
    [ ] Idempotency check
    [ ] Session validation inside txn
    [ ] Simple item resolver: stock validate, price, cost, decrement, stock_movement
    [ ] Composite item resolver (recipeResolver.js): all components, validate, decrement, movements
    [ ] Create pos_sales, items, payments, movements
    [ ] Update cash session totals
    [ ] Write idempotency record
    [ ] Return invoice
[ ] Implement GET /pos/sales/:id
[ ] Implement GET /pos/sales
[ ] Add all shared helpers: money, errors, saleCode, idempotency, stock, recipeResolver
```

---

## Phase 4 — Flutter POS (MVP 1: Simple Items)

```
[ ] Add pos route to Admin Dashboard router
[ ] Add POS to sidebar navigation
[ ] Domain layer: entities, repository interface, usecases
[ ] Data layer: models, remote datasource, local datasource, repository impl
[ ] CashSessionCubit + CashSessionState
[ ] PosProductSearchCubit + PosProductSearchState
[ ] PosCubit + PosState + PosSubmitStatus
[ ] CashSessionScreen + OpenSessionDialog
[ ] PosScreen (two-panel layout, session header, offline banner)
[ ] ProductVariantTile (simple: add button; composite: configure button)
[ ] CurrentSalePanel + PosCartItemTile
[ ] PaymentMethodSelector
[ ] Complete Sale button with all disabled conditions
[ ] SaleSuccessDialog + SaleInvoiceScreen
[ ] StockConflictDialog
[ ] CloseSessionDialog + CloseSessionScreen
[ ] PosSalesHistoryScreen
```

---

## Phase 5 — Flutter POS (MVP 2: Composite Items)

```
[ ] CompositeConfigCubit + CompositeConfigState
[ ] CompositeConfigDialog (with all component types)
[ ] PerfumeOilSelector
[ ] ComponentOptionSelector
[ ] RecipeChangedDialog
[ ] Update PosCartItemTile for composite display
[ ] Update StockConflictDialog for COMPONENT_STOCK_CONFLICT
[ ] Handle recipeChanged in PosCubit
```

---

## Phase 6 — Connectivity and Safety

```
[ ] Add connectivity_plus listener in PosCubit
[ ] Show OfflinePosBanner when offline
[ ] Disable Complete Sale when offline
[ ] Persist cart locally (pos_local_datasource)
[ ] Persist pending idempotencyKey during network failure
[ ] Add retry same sale (same idempotencyKey)
[ ] Never generate new idempotencyKey during unknownResult
```

---

## Phase 7 — Reports

```
[ ] GET /pos/reports/daily
[ ] GET /pos/reports/cashier/:id
[ ] GET /pos/reports/profit
[ ] GET /pos/reports/missing-cost
[ ] Reports UI in Admin Dashboard
[ ] Profit incomplete warnings
[ ] Top products, top composite products, most used oils
```

---

## Phase 8 — Returns (Phase 2)

```
[ ] Create pos_returns Firestore collection
[ ] Implement POST /pos/returns (with component stock increment for composite)
[ ] Create stock_movements type pos_return per item/component
[ ] Reverse revenue and profit
[ ] Update session totals on refund
[ ] Restrict returns to admin/owner
[ ] Returns UI in Admin Dashboard
```

---

## Implementation Order

```
Step 1:  Phase 0 — answer all decisions
Step 2:  Phase 1 — add productType/unitType/costPrice/isSellable to products
Step 3:  Phase 3 — build POS Worker (simple items first)
Step 4:  Phase 4 — build Flutter POS UI (simple items only)
Step 5:  Phase 6 — add connectivity + idempotency safety
Step 6:  Phase 7 — add basic reports
Step 7:  Phase 2 — build recipe system
Step 8:  Phase 3 — extend Worker with composite resolver
Step 9:  Phase 5 — add composite UI to Flutter
Step 10: Phase 8 — add returns
```

Build the Worker before the UI. Never start Flutter before testing the Worker transaction manually.
