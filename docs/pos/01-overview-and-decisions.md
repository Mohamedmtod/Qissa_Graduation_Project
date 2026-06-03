# POS Module — Overview and Final Decisions

## 1. What We Are Building

A POS system for a shop that sells:

```
1. Simple ready-made products (perfumes, bakhoor, accessories)
2. Raw materials sold individually (oils, bottles, bags)
3. Composite perfumes built from flexible recipes
4. Managed by cashiers across shifts
5. Shared inventory with the online store
6. Profit reports per sale and per shift
```

Final decisions:

```
POS inside Admin Dashboard (Flutter Web on laptop)
New Cloudflare POS Worker (separate from orders worker)
Firestore Transactions for stock safety
Firebase Auth with cashier/admin/owner roles
One shared inventory between online orders and POS sales
Final sale requires internet connection
Cash Sessions from version 1
Payment methods recorded only: Cash / Card / InstaPay / Wallet
No barcode in Phase 1
Profit reports after adding costPrice per variant / raw material
Support: simple products + raw materials + composite recipe perfumes
```

---

## 2. Tech Stack Alignment

| Layer | Technology |
|---|---|
| Backend | Cloudflare Workers |
| Auth | Firebase Auth |
| Database | Firestore |
| Admin Dashboard | Flutter Web |
| Stock Safety | Firestore Transactions |
| POS Connectivity | Online-only for final sale |

---

## 3. Architecture Flow

```
Admin Dashboard Flutter Web
        |
        | Firebase Auth Token
        v
Cloudflare POS Worker
        |
        v
Firestore Transaction
        |
        |-- verify user role
        |-- check open cash session
        |-- for simple items: validate + decrement product/variant stock
        |-- for composite items:
        |       resolve recipe
        |       resolve selected components
        |       validate all component stocks
        |       decrement each component stock
        |-- read price / salePrice from database
        |-- read costPrice (per variant or per component)
        |-- create POS sale
        |-- create sale items (with displayNameSnapshot)
        |-- create payment record
        |-- create stock movements
        |-- update cash session totals
        |-- write idempotency record
        |-- return invoice
```

---

## 4. Product Types

Every product must have a `productType`:

### simple
Ready-made product sold as-is. Stock decremented from the product/variant directly.

Examples:
```
Bottled perfumes, bakhoor, incense holders, body splash,
deodorant, diffuser oils (ready), sunglasses, watches
```

### raw_material
Raw ingredient. May be sold directly (`isSellable = true`) or used only as a recipe component.

Examples:
```
Perfume oil concentrate (ml)
Alcohol (ml)
Empty bottles (piece)
Cloth bags (piece)
Plastic bags (piece)
```

Each raw material has:
```
unitType: ml | piece | gram
stock (in that unit)
costPrice per unit
isSellable: true / false
```

### composite
Product sold to customer but stock is not decremented from itself.
Instead, stock is decremented from its recipe components.

Examples:
```
Compound perfume 30ml
Compound perfume 50ml
Compound perfume 100ml
```

A composite product **requires an active recipe** to be sold.

---

## 5. Core Rule: Flutter Is Not the Source of Truth

Flutter sends per item:
```
lineType (simple | composite)
productId
variantId
quantity
for composite: recipeId + selectedComponents + recipeVersion
paymentMethod
```

The Worker is responsible for:
```
reading the final price (salePrice ?? price)
resolving recipe and components
calculating profit from costPrice
validating and decrementing all stock
creating all Firestore documents
```

Flutter **never**:
- Sets the final price
- Decrements stock
- Calculates profit as a source of truth

---

## 6. MVP Scope — Two Phases

### MVP 1 — Simple Products Only (Start Here)

```
Login as cashier / admin
Open cash session
Search products (simple + sellable raw materials)
Select variant → Add to cart
Select payment method
Complete sale (online only)
Update stock safely via Firestore Transaction
Save invoice + session totals
Close cash session
View session summary + basic reports
```

### MVP 2 — Composite Perfumes (Next)

```
Build recipe system (Admin UI)
Select composite variant → Open Composite Config Dialog
Choose perfume oil from available stock
Choose packaging (optional)
Create composite sale
Deduct all component stocks atomically
Composite profit from component costs
Stock movements per component
```

---

## 7. Implementation Order

```
1.  Add productType / unitType / costPrice / isSellable to products
2.  Update Admin product form
3.  Build POS Worker skeleton
4.  Build cash sessions APIs
5.  Build simple + raw material direct sale (MVP 1)
6.  Build Flutter POS (MVP 1 screens only)
7.  Add idempotency + offline handling
8.  Add basic reports
9.  Build recipe system (Admin UI + composite_recipes collection)
10. Add composite sale flow to Worker
11. Add composite sale UI to Flutter (MVP 2)
12. Add returns
```

Do not start with the UI.
Start with the Worker and the transaction — that is the core of the system.
