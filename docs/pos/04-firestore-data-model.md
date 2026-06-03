# POS Module — Firestore Data Model

## Collections

```
products                    ← MODIFY: add productType, unitType, isSellable, costPrice
recipes                     ← NEW (was documented as composite_recipes; actual collection name is recipes)
pos_sales                   ← NEW
pos_sales/{id}/items        ← NEW subcollection
pos_payments                ← NEW
pos_cash_sessions           ← NEW
stock_movements             ← NEW
pos_idempotency             ← NEW
pos_returns                 ← Phase 2
```

---

## 1. Products — New Fields

Add without breaking Orders Worker:

```
products/{productId}
  productType: string    simple | raw_material | composite   ← NEW
  isSellable: boolean                                        ← NEW
  unitType: string       piece | ml | gram                   ← NEW
  (all existing fields remain unchanged)
```

Variant — add only:

```
  costPrice: number | null    ← NEW (required for profit reports)
  unitType: string            ← NEW (inherits from product usually)
```

### productType Examples

```
Bottled perfume:      productType=simple,       unitType=piece, isSellable=true
Diffuser oil ready:   productType=simple,       unitType=piece, isSellable=true
Perfume oil raw:      productType=raw_material, unitType=ml,    isSellable=true
Alcohol:              productType=raw_material, unitType=ml,    isSellable=false
Empty bottle 50ml:    productType=raw_material, unitType=piece, isSellable=false
Cloth bag:            productType=raw_material, unitType=piece, isSellable=false
Compound perfume:     productType=composite,    unitType=piece, isSellable=true
```

---

## 2. recipes

> **Note:** The Firestore collection is named `recipes` (not `composite_recipes`). Both Admin Dashboard and Worker use `recipes`. Docs updated to reflect implementation.

```
recipes/{recipeId}
  productId: string
  variantId: string
  name: string
  isActive: boolean
  recipeVersion: number        ← increment on every edit

  sellingPrice: number | null  ← null = use variant.price
  useVariantPrice: boolean

  components: [
    { ... component objects }
  ]

  createdAt: timestamp
  updatedAt: timestamp
```

### Component Types

**`fixed_product`** — always same ingredient:
```json
{
  "componentType": "fixed_product",
  "productId": "alcohol",
  "variantId": "default",
  "quantity": 35,
  "unitType": "ml"
}
```

**`selected_perfume_oil`** — cashier picks the oil:
```json
{
  "componentType": "selected_perfume_oil",
  "quantity": 15,
  "unitType": "ml",
  "allowedCategory": "perfume_oils"
}
```

**`selectable_product`** — cashier picks from options:
```json
{
  "componentType": "selectable_product",
  "label": "Packaging",
  "quantity": 1,
  "unitType": "piece",
  "optional": true,
  "defaultProductId": "plastic_bag",
  "defaultVariantId": "default",
  "options": [
    { "productId": "plastic_bag", "variantId": "default", "label": "كيس بلاستيك", "priceDelta": 0 },
    { "productId": "cloth_bag",   "variantId": "default", "label": "كيس قماش",    "priceDelta": 10 }
  ]
}
```

---

## 3. pos_sales

```
pos_sales/{saleId}
  saleCode: string              "POS-2026-000001"
  cashierId: string
  cashierNameSnapshot: string
  cashSessionId: string
  status: string                completed | partially_returned | returned | voided
  paymentMethod: string         cash | card | instapay | wallet
  subtotal: number
  discountTotal: number
  total: number
  totalCost: number | null
  grossProfit: number | null
  profitIncomplete: boolean
  itemCount: number
  totalQuantity: number
  idempotencyKey: string
  createdAt: timestamp
  updatedAt: timestamp
```

---

## 4. pos_sales/{saleId}/items/{itemId}

```
  lineType: string              simple | composite
  productId: string
  variantId: string
  recipeId: string | null
  displayNameSnapshot: string   built by Worker from resolved data
  productNameSnapshot: string
  variantLabelSnapshot: string
  selectedComponentsSnapshot: map | null
  originalUnitPriceSnapshot: number
  salePriceSnapshot: number | null
  finalUnitPrice: number
  costPriceSnapshot: number | null
  quantity: number
  returnedQuantity: number
  lineSubtotal: number
  lineCost: number | null
  lineProfit: number | null
  profitIncomplete: boolean
```

---

## 5. pos_payments

```
pos_payments/{paymentId}
  saleId: string
  cashSessionId: string
  cashierId: string
  method: string                cash | card | instapay | wallet
  amount: number
  status: string                "recorded"
  referenceNumber: string | null
  createdAt: timestamp
```

---

## 6. pos_cash_sessions

```
pos_cash_sessions/{sessionId}
  cashierId: string
  cashierNameSnapshot: string
  status: string                open | closed
  openedAt: timestamp
  closedAt: timestamp | null
  openingCash: number
  expectedCash: number          openingCash + all cash sales
  countedCash: number | null
  cashDifference: number | null countedCash - expectedCash
  salesCount: number
  grossSales: number
  netSales: number
  totalCost: number | null
  grossProfit: number | null
  profitIncompleteCount: number
  paymentTotals: { cash, card, instapay, wallet }
  notes: string | null
```

Cash rule: `expectedCash += total` only when `paymentMethod == "cash"`.

---

## 7. stock_movements

```
stock_movements/{movementId}
  productId: string
  variantId: string
  movementType: string
    online_order | pos_simple_sale | pos_composite_component | pos_return | admin_restock | manual_adjustment
  quantityChange: number        negative = removed
  unitType: string              ml | piece | gram
  quantityBefore: number
  quantityAfter: number
  referenceType: string         order | pos_sale | pos_return | admin
  referenceId: string
  parentSaleItemId: string | null
  createdBy: string
  createdAt: timestamp
```

Composite sale example (50ml with Sauvage Oil + cloth bag):
```
oil_sauvage:  movementType=pos_composite_component, quantityChange=-15, unitType=ml
alcohol:      movementType=pos_composite_component, quantityChange=-35, unitType=ml
bottle_50ml:  movementType=pos_composite_component, quantityChange=-1,  unitType=piece
cloth_bag:    movementType=pos_composite_component, quantityChange=-1,  unitType=piece
```

---

## 8. pos_idempotency

```
pos_idempotency/{idempotencyKey}
  saleId: string
  cashierId: string
  createdAt: timestamp
```
