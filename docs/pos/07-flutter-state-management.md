# POS Module — Flutter State Management

## Cubits

| Cubit | Responsibility |
|---|---|
| `CashSessionCubit` | Open / close / monitor the shift session |
| `PosProductSearchCubit` | Search products from the Worker |
| `PosCubit` | Cart, sale submission, connectivity, idempotency |
| `CompositeConfigCubit` | Configure composite item before adding to cart |

---

## CashSessionState

```dart
sealed class CashSessionState {}
class CashSessionInitial extends CashSessionState {}
class CashSessionLoading extends CashSessionState {}
class CashSessionNoOpen extends CashSessionState {}
class CashSessionOpening extends CashSessionState {}
class CashSessionOpen extends CashSessionState {
  final CashSession session;
}
class CashSessionClosing extends CashSessionState {}
class CashSessionClosed extends CashSessionState {
  final CashSessionSummary summary;
}
class CashSessionFailure extends CashSessionState {
  final String message;
}
```

Routing:
```
noOpenSession → show CashSessionScreen / OpenSessionDialog
open          → show PosScreen
closing       → disable Complete Sale
closed        → show summary → redirect to CashSessionScreen
```

---

## PosProductSearchState

```dart
sealed class PosProductSearchState {}
class PosProductSearchInitial extends PosProductSearchState {}
class PosProductSearchLoading extends PosProductSearchState {}
class PosProductSearchLoaded extends PosProductSearchState {
  final List<PosProduct> products;
}
class PosProductSearchEmpty extends PosProductSearchState {}
class PosProductSearchFailure extends PosProductSearchState {
  final String message;
}
```

---

## CompositeConfigState

```dart
sealed class CompositeConfigState {}
class CompositeConfigInitial extends CompositeConfigState {}
class CompositeConfigLoadingRecipe extends CompositeConfigState {}
class CompositeConfigRecipeLoaded extends CompositeConfigState {
  final CompositeRecipe recipe;
  final Map<String, SelectedComponent> currentSelections;
}
class CompositeConfigSearchingOils extends CompositeConfigState {}
class CompositeConfigOilResultsLoaded extends CompositeConfigState {
  final List<PosProduct> oilResults;
  final CompositeRecipe recipe;
  final Map<String, SelectedComponent> currentSelections;
}
class CompositeConfigReadyToAdd extends CompositeConfigState {
  final PosCartItem builtCartItem;
}
class CompositeConfigInvalidSelection extends CompositeConfigState {
  final String reason;
}
class CompositeConfigFailure extends CompositeConfigState {
  final String message;
}
```

Flow:
```
loadRecipe(productId, variantId)   → loadingRecipe → recipeLoaded
searchOils(query)                  → searchingOils → oilResultsLoaded
selectOil(productId, variantId)    → update selections → recipeLoaded
selectOption(label, option)        → update selections → recipeLoaded
confirmSelection()                 → validate → readyToAdd → PosCubit.addCompositeItem()
```

---

## PosState

```dart
class PosState {
  final List<PosCartItem> cartItems;
  final PaymentMethod? selectedPaymentMethod;
  final int displaySubtotal;          // local display only
  final bool isOnline;
  final PosSubmitStatus submitStatus;
  final String currentIdempotencyKey; // NEVER change during unknownResult
  final List<StockConflict> stockConflicts;
  final String? errorMessage;
}
```

---

## PosSubmitStatus

```dart
enum PosSubmitStatus {
  idle,
  submitting,
  success,
  stockConflict,
  componentStockConflict,
  recipeChanged,
  offlineBlocked,
  unknownResult,
  failure,
}
```

| Status | Action |
|---|---|
| `idle` | Button enabled (if conditions met) |
| `submitting` | Button disabled, spinner shown |
| `success` | Show SaleSuccessDialog, clear cart, new idempotencyKey |
| `stockConflict` | Show StockConflictDialog |
| `componentStockConflict` | Show dialog with component details |
| `recipeChanged` | Show RecipeChangedDialog, prompt reconfigure |
| `offlineBlocked` | Show offline banner, button disabled |
| `unknownResult` | Show retry button, keep same idempotencyKey |
| `failure` | Show error message |

---

## Idempotency Key Rule

```dart
// On first attempt:
//   generate UUID → store in state.currentIdempotencyKey

// On unknownResult + retry:
//   send the SAME UUID → Worker returns existing sale or creates once

// On success or non-unknown failure:
//   after cart cleared → generate NEW UUID for next sale

// NEVER generate new UUID while submitStatus == unknownResult
```

---

## Complete Sale Button — Enabled When

```dart
state.cartItems.isNotEmpty &&
state.selectedPaymentMethod != null &&
state.isOnline &&
state.submitStatus != PosSubmitStatus.submitting &&
state.submitStatus != PosSubmitStatus.offlineBlocked
```

---

## Connectivity

```dart
void onConnectivityChanged(bool isOnline) {
  if (!isOnline) {
    emit(state.copyWith(isOnline: false, submitStatus: PosSubmitStatus.offlineBlocked));
  } else {
    emit(state.copyWith(isOnline: true));
    if (state.submitStatus == PosSubmitStatus.offlineBlocked) {
      emit(state.copyWith(submitStatus: PosSubmitStatus.idle));
    }
  }
}
```
