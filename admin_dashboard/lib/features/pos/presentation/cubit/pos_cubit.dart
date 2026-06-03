// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:math';
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import '../../data/repos/pos_repository.dart';

// ---------------------------------------------------------------------------
// Idempotency key — a cryptographically random UUID-like hex string.
// We use dart:math with Random.secure() to avoid adding the `uuid` package.
// ---------------------------------------------------------------------------
String _generateIdempotencyKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Format: 8-4-4-4-12
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

// ---------------------------------------------------------------------------
// Submit status enum — replaces loose isLoading + isCartLocked booleans.
// ---------------------------------------------------------------------------
enum PosSubmitStatus {
  /// Cart is idle; user can add items and submit.
  idle,

  /// Request is in-flight; block duplicate taps.
  submitting,

  /// Sale completed successfully (temporary; cleared on dismissInvoice).
  success,

  /// Network lost AFTER the request was sent — result unknown.
  /// Cart is LOCKED; must retry with the SAME idempotencyKey.
  unknownResult,

  /// Worker returned a known validation error (stock, recipe, etc.).
  /// Cart is NOT locked; user can fix items and re-submit.
  validationError,

  /// Generic failure — cart is NOT locked.
  failure,
}

// ---------------------------------------------------------------------------
// Cart item
// ---------------------------------------------------------------------------
class PosCartItem {
  final InventoryItem product;
  final ProductVariant variant;
  final int quantity;

  PosCartItem({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  double get subtotal {
    final price = variant.salePrice != null && variant.salePrice! > 0
        ? variant.salePrice!
        : variant.price;
    return price * quantity;
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'productName': product.name,
      'productCollection': product.collection,
      'productImageUrl': product.imageUrl,
      'productType': product.productType,
      'variantId': variant.id,
      'variantLabel': variant.label,
      'quantity': quantity,
      'price': variant.price,
      'salePrice': variant.salePrice,
      'costPrice': variant.costPrice,
      'unitType': variant.unitType,
      'stock': variant.stock,
    };
  }

  factory PosCartItem.fromJson(Map<String, dynamic> json) {
    final prod = InventoryItem(
      id: json['productId'] as String? ?? '',
      name: json['productName'] as String? ?? '',
      collection: json['productCollection'] as String? ?? '',
      imageUrl: json['productImageUrl'] as String? ?? '',
      units: (json['stock'] as num?)?.toInt() ?? 0,
      waitingUsers: 0,
      trend: InventoryTrend.up,
      productType: json['productType'] as String? ?? 'simple',
      isSellable: true,
      unitType: json['unitType'] as String? ?? 'piece',
      variants: [
        ProductVariant(
          id: json['variantId'] as String? ?? 'default',
          label: json['variantLabel'] as String? ?? '',
          price: (json['price'] as num?)?.toDouble() ?? 0.0,
          salePrice: (json['salePrice'] as num?)?.toDouble(),
          costPrice: (json['costPrice'] as num?)?.toDouble(),
          unitType: json['unitType'] as String? ?? 'piece',
          stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
        )
      ],
    );
    return PosCartItem(
      product: prod,
      variant: prod.variants.first,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

// ---------------------------------------------------------------------------
// POS state
// ---------------------------------------------------------------------------
class PosState {
  final bool isOnline;
  final PosSubmitStatus submitStatus;
  final List<PosCartItem> cartItems;
  final List<InventoryItem> products;
  final bool isLoadingProducts;
  final String? errorMessage;

  /// The key used for the current/last checkout attempt.
  /// NEVER changes when submitStatus == unknownResult.
  final String currentIdempotencyKey;

  /// The raw payload of the last pending sale (used for retry).
  final Map<String, dynamic>? pendingPayload;

  /// Set on successful checkout; cleared by dismissInvoice().
  final Map<String, dynamic>? successInvoice;

  /// Detailed stock conflicts returned from the server.
  final List<Map<String, dynamic>> stockConflicts;

  /// Past sales history loaded from the worker.
  final List<Map<String, dynamic>> salesHistory;

  /// Status of the sales history API load.
  final bool isLoadingHistory;

  PosState({
    required this.isOnline,
    required this.submitStatus,
    required this.cartItems,
    required this.products,
    required this.isLoadingProducts,
    required this.currentIdempotencyKey,
    this.errorMessage,
    this.pendingPayload,
    this.successInvoice,
    this.stockConflicts = const [],
    this.salesHistory = const [],
    this.isLoadingHistory = false,
  });

  factory PosState.initial() {
    return PosState(
      isOnline: true,
      submitStatus: PosSubmitStatus.idle,
      cartItems: [],
      products: [],
      isLoadingProducts: false,
      currentIdempotencyKey: _generateIdempotencyKey(),
      stockConflicts: const [],
      salesHistory: const [],
      isLoadingHistory: false,
    );
  }

  // Convenience getters for backwards-compatible UI checks.
  bool get isLoading =>
      submitStatus == PosSubmitStatus.submitting || isLoadingProducts;
  bool get isCartLocked => submitStatus == PosSubmitStatus.unknownResult;

  double get totalAmount =>
      cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

  PosState copyWith({
    bool? isOnline,
    PosSubmitStatus? submitStatus,
    List<PosCartItem>? cartItems,
    List<InventoryItem>? products,
    bool? isLoadingProducts,
    String? currentIdempotencyKey,
    String? errorMessage,
    Map<String, dynamic>? pendingPayload,
    Map<String, dynamic>? successInvoice,
    List<Map<String, dynamic>>? stockConflicts,
    List<Map<String, dynamic>>? salesHistory,
    bool? isLoadingHistory,
    bool clearInvoice = false,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return PosState(
      isOnline: isOnline ?? this.isOnline,
      submitStatus: submitStatus ?? this.submitStatus,
      cartItems: cartItems ?? this.cartItems,
      products: products ?? this.products,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      currentIdempotencyKey:
          currentIdempotencyKey ?? this.currentIdempotencyKey,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingPayload:
          clearPending ? null : (pendingPayload ?? this.pendingPayload),
      successInvoice:
          clearInvoice ? null : (successInvoice ?? this.successInvoice),
      stockConflicts: clearError ? const [] : (stockConflicts ?? this.stockConflicts),
      salesHistory: salesHistory ?? this.salesHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }
}

// ---------------------------------------------------------------------------
// PosCubit
// ---------------------------------------------------------------------------
class PosCubit extends Cubit<PosState> {
  final PosRepository _repository;
  StreamSubscription? _onlineSub;
  StreamSubscription? _offlineSub;

  PosCubit(this._repository) : super(PosState.initial()) {
    _initConnectivity();
    _loadInitialState();
  }

  // ---- Connectivity --------------------------------------------------------

  void _initConnectivity() {
    if (kIsWeb) {
      emit(state.copyWith(isOnline: html.window.navigator.onLine));
      _onlineSub =
          html.window.onOnline.listen((_) => _updateOnlineStatus(true));
      _offlineSub =
          html.window.onOffline.listen((_) => _updateOnlineStatus(false));
    }
  }

  void _updateOnlineStatus(bool online) {
    emit(state.copyWith(isOnline: online));
  }

  // ---- Bootstrap -----------------------------------------------------------

  void _loadInitialState() {
    final isLocked = _repository.local.isCartLocked();
    final pendingPayload = _repository.local.getPendingPayload();

    // Recover persisted idempotency key if the cart is still locked.
    String idempotencyKey = state.currentIdempotencyKey;
    if (isLocked && pendingPayload != null) {
      final savedKey = _repository.local.getIdempotencyKey();
      if (savedKey != null && savedKey.isNotEmpty) {
        idempotencyKey = savedKey;
      }
    }

    emit(state.copyWith(
      submitStatus:
          isLocked ? PosSubmitStatus.unknownResult : PosSubmitStatus.idle,
      pendingPayload: pendingPayload,
      currentIdempotencyKey: idempotencyKey,
    ));

    loadProducts();
  }

  // ---- Products ------------------------------------------------------------

  Future<void> loadProducts() async {
    emit(state.copyWith(isLoadingProducts: true, clearError: true));
    try {
      final prods = await _repository.searchPosProducts();

      // Hydrate cart from local cache using the freshly loaded product list.
      final cachedCart = _repository.local.getCartItems();
      final hydratedCart = <PosCartItem>[];
      for (final cached in cachedCart) {
        final prodId = cached['productId'] as String?;
        final varId = cached['variantId'] as String?;
        final qty = (cached['quantity'] as num?)?.toInt() ?? 1;
        if (prodId == null || varId == null) continue;

        final prod = prods.firstWhere((p) => p.id == prodId,
            orElse: () => _emptyProduct(prodId));
        if (prod.id.isNotEmpty) {
          final variant = prod.variants.firstWhere((v) => v.id == varId,
              orElse: () => prod.variants.first);
          hydratedCart
              .add(PosCartItem(product: prod, variant: variant, quantity: qty));
        } else {
          try {
            hydratedCart.add(PosCartItem.fromJson(cached));
          } catch (_) {}
        }
      }

      emit(state.copyWith(
        products: prods,
        cartItems: hydratedCart,
        isLoadingProducts: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingProducts: false,
        errorMessage: 'Failed to load products: $e',
      ));
    }
  }

  InventoryItem _emptyProduct(String id) {
    return const InventoryItem(
      id: '',
      name: '',
      collection: '',
      imageUrl: '',
      units: 0,
      waitingUsers: 0,
      trend: InventoryTrend.up,
      productType: 'simple',
      isSellable: false,
      unitType: 'piece',
      variants: [],
    );
  }

  // ---- Cart ----------------------------------------------------------------

  void addToCart(InventoryItem product, ProductVariant variant) {
    if (state.isCartLocked) return;

    final existingIndex = state.cartItems.indexWhere(
      (item) =>
          item.product.id == product.id && item.variant.id == variant.id,
    );

    final updated = List<PosCartItem>.from(state.cartItems);
    if (existingIndex != -1) {
      final current = updated[existingIndex];
      updated[existingIndex] = PosCartItem(
        product: product,
        variant: variant,
        quantity: current.quantity + 1,
      );
    } else {
      updated.add(PosCartItem(product: product, variant: variant, quantity: 1));
    }

    _saveLocalCart(updated);
    emit(state.copyWith(cartItems: updated, clearInvoice: true));
  }

  void updateQuantity(PosCartItem item, int delta) {
    if (state.isCartLocked) return;

    final idx = state.cartItems.indexOf(item);
    if (idx == -1) return;

    final updated = List<PosCartItem>.from(state.cartItems);
    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      updated.removeAt(idx);
    } else {
      updated[idx] = PosCartItem(
        product: item.product,
        variant: item.variant,
        quantity: newQty,
      );
    }

    _saveLocalCart(updated);
    emit(state.copyWith(cartItems: updated, clearInvoice: true));
  }

  void removeFromCart(PosCartItem item) {
    if (state.isCartLocked) return;
    final updated = List<PosCartItem>.from(state.cartItems)..remove(item);
    _saveLocalCart(updated);
    emit(state.copyWith(cartItems: updated, clearInvoice: true));
  }

  void clearCart() {
    if (state.isCartLocked) return;
    _saveLocalCart([]);
    emit(state.copyWith(cartItems: [], clearInvoice: true));
  }

  void _saveLocalCart(List<PosCartItem> items) {
    final list = items.map((it) => it.toJson()).toList();
    _repository.local.saveCartItems(list);
  }

  // ---- Checkout ------------------------------------------------------------

  Future<void> checkout({
    required String sessionId,
    required String paymentMethod,
  }) async {
    // Guard: cannot checkout when locked, cart empty, or already submitting.
    if (state.isCartLocked ||
        state.cartItems.isEmpty ||
        state.submitStatus == PosSubmitStatus.submitting) {
      return;
    }

    // CRITICAL: only generate a new key when we are NOT in unknownResult.
    // On unknownResult the user is retrying and we MUST reuse the same key.
    final idempotencyKey = state.submitStatus == PosSubmitStatus.unknownResult
        ? state.currentIdempotencyKey
        : _generateIdempotencyKey();

    final itemsPayload = state.cartItems.map((it) => it.toJson()).toList();
    final payload = {
      'idempotencyKey': idempotencyKey,
      'sessionId': sessionId,
      'items': itemsPayload,
      'paymentMethod': paymentMethod,
    };

    emit(state.copyWith(
      submitStatus: PosSubmitStatus.submitting,
      currentIdempotencyKey: idempotencyKey,
      clearError: true,
      stockConflicts: const [],
    ));

    try {
      final res = await _repository.checkoutSale(
        sessionId: sessionId,
        items: itemsPayload,
        paymentMethod: paymentMethod,
        idempotencyKey: idempotencyKey,
      );

      // Success — generate fresh key for the NEXT sale.
      _saveLocalCart([]);
      emit(state.copyWith(
        submitStatus: PosSubmitStatus.success,
        cartItems: [],
        successInvoice: res,
        currentIdempotencyKey: _generateIdempotencyKey(),
        clearPending: true,
      ));
    } catch (e) {
      debugPrint('[PosCubit] checkout error: $e');
      if (e is DioException) {
        debugPrint('[PosCubit] checkout response data: ${e.response?.data}');
      }
      final isLocked = _repository.local.isCartLocked();

      if (isLocked) {
        // Network lost mid-flight — lock the cart; keep same idempotencyKey.
        emit(state.copyWith(
          submitStatus: PosSubmitStatus.unknownResult,
          pendingPayload: payload,
          errorMessage:
              'Result unknown (network lost). Cart locked — please retry.',
        ));
      } else {
        // Server returned a known validation error.
        var errorMsg = e.toString();
        var conflicts = <Map<String, dynamic>>[];
        if (e is DioException && e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['error'] == 'STOCK_CONFLICT') {
            errorMsg = 'Stock conflict detected. Some items are out of stock.';
            final details = data['details'];
            if (details is List) {
              conflicts = details.map((c) => Map<String, dynamic>.from(c as Map)).toList();
            }
          } else {
            errorMsg = data['error']?.toString() ?? e.toString();
          }
        }
        emit(state.copyWith(
          submitStatus: PosSubmitStatus.validationError,
          errorMessage: 'Checkout failed: $errorMsg',
          stockConflicts: conflicts,
        ));
      }
    }
  }

  // ---- Retry ---------------------------------------------------------------

  Future<void> retryCheckout() async {
    final pending = state.pendingPayload;
    if (pending == null) return;

    // Reuse exact same payload (and idempotencyKey inside it).
    emit(state.copyWith(
        submitStatus: PosSubmitStatus.submitting, clearError: true, stockConflicts: const []));

    try {
      final res = await _repository.retryCheckoutSale(pending);
      _saveLocalCart([]);
      emit(state.copyWith(
        submitStatus: PosSubmitStatus.success,
        cartItems: [],
        successInvoice: res,
        currentIdempotencyKey: _generateIdempotencyKey(),
        clearPending: true,
      ));
    } catch (e) {
      debugPrint('[PosCubit] retryCheckout error: $e');
      if (e is DioException) {
        debugPrint('[PosCubit] retryCheckout response data: ${e.response?.data}');
      }
      var errorMsg = e.toString();
      var conflicts = <Map<String, dynamic>>[];
      var isValidationError = false;

      if (e is DioException && e.response != null) {
        final statusCode = e.response!.statusCode;
        isValidationError = statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 409 || statusCode == 404;
      }

      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data['error'] == 'STOCK_CONFLICT') {
          errorMsg = 'Stock conflict detected. Some items are out of stock.';
          final details = data['details'];
          if (details is List) {
            conflicts = details.map((c) => Map<String, dynamic>.from(c as Map)).toList();
          }
        } else {
          errorMsg = data['error']?.toString() ?? e.toString();
        }
      }

      if (isValidationError) {
        _repository.local.clearPendingSale();
        emit(state.copyWith(
          submitStatus: PosSubmitStatus.validationError,
          errorMessage: 'Checkout failed: $errorMsg',
          stockConflicts: conflicts,
          clearPending: true,
        ));
      } else {
        emit(state.copyWith(
          submitStatus: PosSubmitStatus.unknownResult,
          errorMessage: 'Retry failed: $errorMsg. Check your connection and try again.',
          stockConflicts: conflicts,
        ));
      }
    }
  }

  // ---- Force unlock --------------------------------------------------------

  void forceUnlock() {
    _repository.local.clearPendingSale();
    emit(state.copyWith(
      submitStatus: PosSubmitStatus.idle,
      clearPending: true,
      clearError: true,
      currentIdempotencyKey: _generateIdempotencyKey(),
    ));
  }

  // ---- Dismiss invoice -----------------------------------------------------

  void dismissInvoice() {
    emit(state.copyWith(
      submitStatus: PosSubmitStatus.idle,
      clearInvoice: true,
    ));
  }

  void clearError() {
    emit(state.copyWith(
      clearError: true,
      submitStatus: state.submitStatus == PosSubmitStatus.validationError
          ? PosSubmitStatus.idle
          : state.submitStatus,
    ));
  }

  // ---- Sales History -------------------------------------------------------

  Future<void> loadSalesHistory() async {
    emit(state.copyWith(isLoadingHistory: true, clearError: true));
    try {
      final history = await _repository.getSales();
      emit(state.copyWith(
        salesHistory: history,
        isLoadingHistory: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingHistory: false,
        errorMessage: 'Failed to load sales history: $e',
      ));
    }
  }

  // ---- Dispose -------------------------------------------------------------

  @override
  Future<void> close() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    return super.close();
  }
}
