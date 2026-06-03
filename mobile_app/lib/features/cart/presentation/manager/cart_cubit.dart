import 'dart:async';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/core/constants/constants.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final CartRepo cartRepo;
  final AuthBloc authBloc;
  final ProductRepo productRepo;
  StreamSubscription? _cartSubscription;
  StreamSubscription? _authSubscription;
  String? _activeUid;

  CartCubit({
    required this.cartRepo,
    required this.authBloc,
    required this.productRepo,
  }) : super(CartInitial()) {
    // Auto-init cart when auth state changes
    _authSubscription = authBloc.stream.listen((authState) {
      final targetUid = (authState.status == AuthStatus.authenticated &&
              authState.user != null)
          ? authState.user!.uid
          : CartRepo.guestCartUserId;

      if (_activeUid == targetUid) return;

      if (targetUid != CartRepo.guestCartUserId) {
        unawaited(_mergeGuestCartAndListen(targetUid));
      } else {
        _startListening(targetUid);
      }
    });

    // Start listening immediately (stream only delivers future events)
    initCart();
  }

  void initCart() {
    final user = authBloc.state.user;
    if (user != null) {
      _startListening(user.uid);
    } else {
      _startListening(CartRepo.guestCartUserId);
    }
  }

  Future<void> _mergeGuestCartAndListen(String uid) async {
    try {
      await cartRepo.mergeGuestCartIntoUser(uid);
    } catch (e) {
      log('[CartCubit] Failed to merge guest cart into user cart: $e', error: e);
      _emitMergeWarning("Failed to merge some guest cart items");
    }
    if (!isClosed) {
      _startListening(uid);
    }
  }

  void _emitMergeWarning(String message) {
    final currentState = state;
    emit(CartMergeWarning(message));
    if (currentState is CartLoaded) {
      emit(
        CartLoaded(items: currentState.items, subtotal: currentState.subtotal),
      );
    }
  }

  void _startListening(String uid) {
    log('[CartCubit] _startListening for uid=$uid');
    _activeUid = uid;
    emit(CartLoading());
    _cartSubscription?.cancel();
    _cartSubscription = cartRepo
        .streamCart(uid)
        .listen(
          (items) async {
            if (_activeUid != uid || isClosed) return;
            log('[CartCubit] Stream received ${items.length} items');
            final visibleItems = <CartItemModel>[];
            final products = await _fetchProductsForCartItems(items);
            if (_activeUid != uid || isClosed) return;
            log('[CartCubit] Fetched ${products.length} products for ${items.length} cart items');
            final productsById = {
              for (final product in products) product.id: product,
            };

            for (final item in items) {
              final product = productsById[item.productId];
              if (product == null || !product.isActive) {
                log('[CartCubit] REMOVING item ${item.productId} (product=${product == null ? "null" : "inactive"})');
                try {
                  await cartRepo.removeFromCart(uid, item.cartDocumentId);
                } catch (_) {
                  // Ignore cleanup failures; the next stream refresh will retry.
                }
                continue;
              }
              visibleItems.add(item);
            }

            if (_activeUid != uid || isClosed) return;
            final subtotal = visibleItems.fold<double>(
              0,
              (sum, item) => sum + (item.price * item.quantity),
            );
            log('[CartCubit] Emitting CartLoaded with ${visibleItems.length} items, subtotal=$subtotal');
            emit(CartLoaded(items: visibleItems, subtotal: subtotal));
          },
          onError: (error) {
            if (_activeUid != uid || isClosed) return;
            log('[CartCubit] Stream ERROR: $error');
            emit(CartError(error.toString()));
          },
        );
  }

  Future<List<ProductModel>> _fetchProductsForCartItems(
    List<CartItemModel> items,
  ) async {
    final productIds = items.map((item) => item.productId).toList();
    if (productIds.isEmpty) return const [];

    try {
      return await productRepo.fetchProductsByIds(productIds);
    } catch (_) {
      final products = <ProductModel>[];
      for (final productId in productIds) {
        final product = await productRepo.streamProductById(productId).first;
        if (product != null) {
          products.add(product);
        }
      }
      return products;
    }
  }

  Future<void> updateQuantity(String itemId, int newQuantity) async {
    log('[CartCubit] updateQuantity: itemId=$itemId, newQty=$newQuantity');
    final user = authBloc.state.user;
    final uid = user?.uid ?? CartRepo.guestCartUserId;

    if (newQuantity == 0) {
      await removeFromCart(itemId);
      return;
    }

    if (newQuantity < 0) return;

    // Stock validation: check if the new quantity exceeds available stock
    try {
      final cartItem = _currentCartItem(itemId);
      final productId = cartItem?.productId ?? itemId;
      final variantId = cartItem?.variantId ?? CartItemModel.defaultVariantId;
      final cartDocumentId = cartItem?.cartDocumentId ?? itemId;

      final product = await productRepo.streamProductById(productId).first;
      if (product == null || !product.isActive) {
        await removeFromCart(cartDocumentId);
        _emitStockError("Product not available anymore");
        return;
      }

      var variantStock = product.defaultVariant.stock;
      for (final variant in product.variants) {
        if (variant.id == variantId) {
          variantStock = variant.stock;
          break;
        }
      }

      if (newQuantity > variantStock) {
        _emitStockError("Only $variantStock items available in stock");
        return;
      }

      await cartRepo.updateQuantity(uid, cartDocumentId, newQuantity);
    } catch (e) {
      _emitStockError("Failed to update quantity");
    }
  }

  CartItemModel? _currentCartItem(String itemId) {
    final currentState = state;
    if (currentState is! CartLoaded) return null;
    for (final item in currentState.items) {
      if (item.cartDocumentId == itemId || item.productId == itemId) {
        return item;
      }
    }
    return null;
  }

  /// Emits a stock error message, then re-emits the current CartLoaded state
  /// so the UI can show a SnackBar without losing the cart list.
  void _emitStockError(String message) {
    final currentState = state;
    emit(CartStockError(message));
    if (currentState is CartLoaded) {
      emit(
        CartLoaded(items: currentState.items, subtotal: currentState.subtotal),
      );
    }
  }

  Future<void> removeFromCart(String itemId) async {
    final user = authBloc.state.user;
    final uid = user?.uid ?? CartRepo.guestCartUserId;

    try {
      await cartRepo.removeFromCart(uid, itemId);
    } catch (e) {
      // Error handled by UI/Stream
    }
  }

  Future<void> clearCart() async {
    final user = authBloc.state.user;
    final uid = user?.uid ?? CartRepo.guestCartUserId;

    try {
      await cartRepo.clearCart(uid);
    } catch (e) {
      // Re-throw so the UI can await the actual success and block if necessary
      throw Exception('Failed to clear cart: $e');
    }
  }

  @override
  Future<void> close() {
    _cartSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}
