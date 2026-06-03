part of 'wishlist_cubit.dart';

abstract class WishlistState {}

class WishlistInitial extends WishlistState {}

class WishlistLoading extends WishlistState {}

class WishlistLoaded extends WishlistState {
  final List<WishlistItemModel> items;
  final List<ProductModel> products;

  WishlistLoaded({required this.items, required this.products});
}

class WishlistError extends WishlistState {
  final String message;
  WishlistError(this.message);
}
