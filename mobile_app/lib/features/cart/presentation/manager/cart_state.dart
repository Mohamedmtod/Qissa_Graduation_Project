part of 'cart_cubit.dart';

abstract class CartState {}

class CartInitial extends CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final List<CartItemModel> items;
  final double subtotal;

  double get shipping => AppConstants.defaultShippingFee;
  double get discount => AppConstants.defaultDiscount;

  double get total {
    final calculated = subtotal + shipping - discount;
    return calculated < 0 ? 0 : calculated;
  }

  CartLoaded({required this.items, required this.subtotal});
}

class CartError extends CartState {
  final String message;
  CartError(this.message);
}

/// Temporary state emitted when a stock limit is reached.
/// The UI should show a SnackBar then the state returns to CartLoaded.
class CartStockError extends CartState {
  final String message;
  CartStockError(this.message);
}

class CartMergeWarning extends CartState {
  final String message;
  CartMergeWarning(this.message);
}
