# POS Module — Flutter Structure (Admin Dashboard)

## Feature Folder Layout

```
admin_dashboard/lib/features/pos/
  presentation/
    screens/
      pos_screen.dart
      sale_invoice_screen.dart
      cash_session_screen.dart
      close_session_screen.dart
      pos_sales_history_screen.dart
      pos_reports_screen.dart
    widgets/
      pos_search_bar.dart
      product_results_panel.dart
      product_variant_tile.dart
      composite_config_dialog.dart
      perfume_oil_selector.dart
      component_option_selector.dart
      current_sale_panel.dart
      pos_cart_item_tile.dart
      payment_method_selector.dart
      open_session_dialog.dart
      close_session_dialog.dart
      sale_success_dialog.dart
      stock_conflict_dialog.dart
      recipe_changed_dialog.dart
      offline_pos_banner.dart
      session_status_card.dart
    cubit/
      pos_cubit.dart
      pos_state.dart
      pos_product_search_cubit.dart
      pos_product_search_state.dart
      cash_session_cubit.dart
      cash_session_state.dart
      composite_config_cubit.dart
      composite_config_state.dart
  domain/
    entities/
      pos_product.dart
      pos_variant.dart
      composite_recipe.dart
      recipe_component.dart
      selected_component.dart
      pos_cart_item.dart
      pos_sale.dart
      pos_sale_item.dart
      cash_session.dart
      payment_method.dart
    repositories/
      pos_repository.dart
    usecases/
      search_pos_products.dart
      get_composite_recipe.dart
      search_perfume_oils.dart
      configure_composite_item.dart
      add_item_to_cart.dart
      update_cart_quantity.dart
      remove_cart_item.dart
      complete_pos_sale.dart
      open_cash_session.dart
      close_cash_session.dart
      get_current_cash_session.dart
  data/
    models/
      pos_product_model.dart
      pos_variant_model.dart
      composite_recipe_model.dart
      create_pos_sale_request_model.dart
      pos_sale_model.dart
      cash_session_model.dart
    datasources/
      pos_remote_datasource.dart
      pos_local_datasource.dart
    repositories/
      pos_repository_impl.dart
```

---

## POS UI Layout

```
+----------------------------------------------------------------+
| Qissa POS        Session: Open        Cashier: Mohamed         |
+----------------------------------------------------------------+
| Search product                                                 |
+-----------------------------------+----------------------------+
| Products                          | Current Invoice            |
|                                   |                            |
| Dior Sauvage (simple)             | Dior Sauvage 100ml  x1     |
| [50ml]  1800  stock: 4  [+Add]    | +  -  remove               |
| [100ml] 2700  stock: 2  [+Add]    |                            |
|                                   | عطر تركيب 50ml             |
| عطر تركيب (composite)             | Sauvage Oil - كيس قماش x1  |
| [30ml]  [Configure →]             | +  -  remove               |
| [50ml]  [Configure →]             |                            |
|                                   | Subtotal: 5400 EGP         |
|                                   | Payment: [ Cash ▼ ]        |
|                                   |                            |
|                                   | [ Complete Sale ]          |
+-----------------------------------+----------------------------+
```

---

## UI Rules

```
Complete Sale disabled when:
  - cart is empty
  - no payment method selected
  - offline
  - submitStatus == submitting
  - submitStatus == offlineBlocked

Composite variant → tap → opens CompositeConfigDialog (NOT added directly)
Simple variant with stock = 0 → shown disabled

After success: show SaleSuccessDialog → clear cart → new idempotencyKey
After stockConflict: show StockConflictDialog with affected items
After componentStockConflict: show dialog with component details
After recipeChanged: show RecipeChangedDialog → reconfigure or remove item
After unknownResult: show Retry button (same idempotencyKey, same request)
```

---

## Cart Item Display

```
Simple:    "Dior Sauvage 100ml  x2  →  5400 EGP"
Composite: "عطر تركيب 50ml  x1  →  860 EGP"
              └ Sauvage Oil · كيس قماش
```

`displayName` is built locally in Flutter for UX.
`displayNameSnapshot` is built by the Worker from resolved components and stored in Firestore.

---

## Architecture Notes

- Follow Clean Architecture: `data` → `domain` → `presentation`.
- State management: Cubit (matches existing admin dashboard pattern).
- Cart subtotal calculations are local (UX only). Final prices come from Worker response.
- `pos_local_datasource.dart`: persists cart and pending idempotencyKey during connectivity loss.
- `CompositeConfigCubit`: manages dialog flow — load recipe → search oils → validate → build cart item.
