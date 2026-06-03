# POS Module — Business Rules and Scenarios

## Rules

1. **Every product must have `productType`**: `simple` | `raw_material` | `composite`
2. **`isSellable` controls if raw_material can be sold at POS** — alcohol=false, ready oil=true
3. **Composite requires active recipe** — reject with `NO_ACTIVE_RECIPE` if none
4. **Recipe quantities live in Firestore** — nothing hardcoded in Worker code
5. **Price set by backend** — Flutter sends productId/variantId only, never price
6. **Cashier cannot apply discounts** — discounts via admin-set `salePrice` only
7. **Missing `costPrice` does not block sale** — sets `profitIncomplete = true`
8. **No sale without open cash session** — reject with `NO_OPEN_SESSION`
9. **No final sale without internet** — Flutter disables button when offline
10. **Stock movement mandatory for every stock change** — one per simple item, one per composite component
11. **Completed sale cannot be directly edited** — use return/void/adjustment

---

## Create Sale Transaction — Step by Step

```
1.  Auth + role check (cashier/admin/owner)
2.  Check idempotencyKey → if exists, return existing sale (EXIT)
3.  Begin Firestore transaction
4.  Read + validate cash session (inside txn): exists, open, belongs to cashier
5.  For each item:
    SIMPLE:
      Read product+variant (inside txn)
      Validate active, isSellable, stock >= quantity
      Calculate: finalUnitPrice = salePrice ?? price
      Calculate: lineCost = costPrice * qty (null if missing)
      Prepare: decrement variant.stock
      Prepare: stock_movement (pos_simple_sale)

    COMPOSITE:
      Read recipe (inside txn): active, recipeVersion matches sent version
      Call recipeResolver → resolved components
      For each component: validate active + stock >= required
      Calculate: finalUnitPrice = (recipe.sellingPrice ?? variant.price) + priceDelta
      Calculate: lineCost = sum(component.costPrice * qty) (null if any missing)
      Prepare: decrement each component's stock
      Prepare: stock_movement per component (pos_composite_component)

6.  Write pos_sales document
7.  Write pos_sales/{id}/items documents
8.  Write pos_payments document
9.  Write stock_movements documents
10. Update pos_cash_sessions:
      salesCount += 1
      grossSales += total
      paymentTotals[method] += total
      if method == cash: expectedCash += total
      if profitComplete: totalCost += cost; grossProfit += profit
11. Write pos_idempotency/{key}
12. Commit
13. Return invoice
```

If transaction fails at any step → rollback → nothing written.

---

## Pricing

```
Simple/Raw:   finalUnitPrice = salePrice ?? price
Composite:    finalUnitPrice = (recipe.sellingPrice ?? variant.price) + priceDelta
              priceDelta = sum of selected selectable_product options priceDelta
```

---

## Worst-Case Scenarios

| # | Scenario | Resolution |
|---|---|---|
| 1 | Online order + POS race on last unit | Firestore txn → one wins, one gets STOCK_CONFLICT |
| 2 | Online order buys oil used in composite | Worker validates component stock in txn → COMPONENT_STOCK_CONFLICT |
| 3 | Cart open, stock changes | Worker validates at write time → STOCK_CONFLICT |
| 4 | Internet lost before Complete Sale | Cart preserved locally, button disabled, nothing sent |
| 5 | Internet lost after Complete Sale | Show unknownResult → retry with same idempotencyKey |
| 6 | Cashier presses Complete Sale twice | Flutter disables button + backend idempotency |
| 7 | Recipe changed while cart open | Worker checks recipeVersion → RECIPE_CHANGED → Flutter prompts reconfigure |
| 8 | Selected bag out of stock | COMPONENT_STOCK_CONFLICT → Flutter shows conflict dialog |
| 9 | Missing costPrice in component | Sale proceeds, profitIncomplete = true, report flags it |
| 10 | Session closed during sale | Worker checks session inside txn → SESSION_CLOSED |
| 11 | Firestore txn fails | TRANSACTION_FAILED, nothing written (atomic) |
| 12 | Composite return (Phase 2) | Linked to current session, each component stock incremented individually |
