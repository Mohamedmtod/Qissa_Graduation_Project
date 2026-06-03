import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/orders/data/models/order_item_model.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

abstract class OrderState {}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderRequestCreated extends OrderState {
  final String orderId;
  final String? orderCode;

  OrderRequestCreated({required this.orderId, this.orderCode});
}

class OrderError extends OrderState {
  final String message;
  OrderError(this.message);
}

class OrderCubit extends Cubit<OrderState> {
  static const Uuid _uuid = Uuid();

  final OrderRepo orderRepo;
  final EventRepo eventRepo;
  final UserTasteRepo? userTasteRepo;
  String? _restockRequestId;
  String? _activeCheckoutAttemptKey;
  String? _activeCheckoutFingerprint;

  OrderCubit({
    required this.orderRepo,
    required this.eventRepo,
    this.userTasteRepo,
  }) : super(OrderInitial());

  void setRestockRequestId(String? restockRequestId) {
    final normalized = restockRequestId?.trim();
    _restockRequestId = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
  }

  Future<void> placeOrder({
    required String userId,
    required List<CartItemModel> cartItems,
    required double total,
    required String address,
    required String phone,
    required String paymentMethod,
    String? notes,
    String referralSource = 'app',
    String? restockRequestId,
    // Shipping zone fields (sent to worker for server-side validation)
    String? shippingZoneCode,
    String? shippingGovernorate,
    double? clientShippingFee,
  }) async {
    if (state is OrderLoading) {
      return;
    }

    emit(OrderLoading());

    try {
      // Convert cart items to order items
      final orderItems = cartItems.map((cartItem) {
        return OrderItemModel(
          productId: cartItem.productId,
          variantId: cartItem.variantId,
          variantLabel: cartItem.variantLabel,
          name: cartItem.name,
          priceSnapshot: cartItem.price,
          quantity: cartItem.quantity,
        );
      }).toList();

      final orderSource = _resolveOrderSource(
        cartItems: cartItems,
        referralSource: referralSource,
      );
      final attributionMetadata = _buildAttributionMetadata(
        orderSource: orderSource,
        restockRequestId: restockRequestId ?? _restockRequestId,
      );
      final attemptFingerprint = _buildCheckoutAttemptFingerprint(
        userId: userId,
        cartItems: cartItems,
        address: address,
        phone: phone,
        paymentMethod: paymentMethod,
        notes: notes,
        orderSource: orderSource,
        attributionMetadata: attributionMetadata,
        shippingZoneCode: shippingZoneCode,
      );
      final idempotencyKey = _checkoutAttemptKeyFor(
        userId: userId,
        fingerprint: attemptFingerprint,
      );

      // Create the order model
      final order = OrderModel(
        id: '', // Firestore will generate the ID
        userId: userId,
        orderSource: orderSource,
        items: orderItems,
        total: total,
        status: 'pending',
        address: address,
        phone: phone,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: Timestamp.now(),
        attributionMetadata: attributionMetadata,
      );

      // Save order to Firestore via worker
      final createdOrder = await orderRepo.createOrder(
        order,
        idempotencyKey: idempotencyKey,
        shippingZoneCode: shippingZoneCode,
        shippingGovernorate: shippingGovernorate,
        clientShippingFee: clientShippingFee,
      );
      _clearCheckoutAttempt();

      // Instantly finish the command intent processing.
      // Order observation (the query side) is strictly handed off to MyOrdersPage.
      emit(
        OrderRequestCreated(
          orderId: createdOrder.orderId,
          orderCode: createdOrder.orderCode,
        ),
      );

      // Log Order Request event (the user initiated the order)
      Future<void>(() async {
        try {
          await eventRepo.logOrderRequest(
            orderId: createdOrder.orderId,
            total: total,
            itemCount: orderItems.length,
            items: orderItems
                .map(
                  (item) => {
                    'productId': item.productId,
                    'variantId': item.variantId,
                    if (item.variantLabel.isNotEmpty)
                      'variantLabel': item.variantLabel,
                    'name': item.name,
                    'quantity': item.quantity,
                    'priceSnapshot': item.priceSnapshot,
                  },
                )
                .toList(),
          );
        } catch (e) {
          // Analytics failure shouldn't block the order success flow
          debugPrint('Non-fatal analytics error: $e');
        }

        try {
          final purchaseNotes = cartItems.expand((item) => item.notes).toList();
          await userTasteRepo?.recordEvent(
            eventType: EventType.purchase,
            notes: purchaseNotes,
            userId: userId,
          );
        } catch (e) {
          debugPrint('Non-fatal taste tracking error: $e');
        }
      });
    } catch (e) {
      // Failed to create the order document at all
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      emit(OrderError('Failed to place order: $errorMessage'));
    }
  }

  String _checkoutAttemptKeyFor({
    required String userId,
    required String fingerprint,
  }) {
    if (_activeCheckoutAttemptKey == null ||
        _activeCheckoutFingerprint != fingerprint) {
      _activeCheckoutFingerprint = fingerprint;
      _activeCheckoutAttemptKey = '${userId}_${_uuid.v4()}';
    }
    return _activeCheckoutAttemptKey!;
  }

  void _clearCheckoutAttempt() {
    _activeCheckoutAttemptKey = null;
    _activeCheckoutFingerprint = null;
  }

  String _buildCheckoutAttemptFingerprint({
    required String userId,
    required List<CartItemModel> cartItems,
    required String address,
    required String phone,
    required String paymentMethod,
    required String? notes,
    required String orderSource,
    required Map<String, dynamic>? attributionMetadata,
    String? shippingZoneCode,
  }) {
    final itemParts =
        cartItems
            .map(
              (item) =>
                  '${item.productId.trim()}:${item.variantId.trim()}:${item.quantity}',
            )
            .toList()
          ..sort();
    return [
      userId.trim(),
      itemParts.join('|'),
      address.trim(),
      phone.trim(),
      paymentMethod.trim(),
      notes?.trim() ?? '',
      orderSource,
      attributionMetadata?['restockRequestId']?.toString().trim() ?? '',
      shippingZoneCode?.trim() ?? '',
    ].join('\n');
  }

  Map<String, dynamic>? _buildAttributionMetadata({
    required String orderSource,
    required String? restockRequestId,
  }) {
    if (orderSource != 'restock_alert') {
      return null;
    }
    final normalized = restockRequestId?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return {'restockRequestId': normalized};
  }

  String _resolveOrderSource({
    required List<CartItemModel> cartItems,
    required String referralSource,
  }) {
    final normalizedReferralSource = referralSource.trim().toLowerCase();
    if (normalizedReferralSource == 'restock_alert') {
      return 'restock_alert';
    }

    final bool isAIChatOrder = cartItems.any(
      (item) => item.source == 'ai_chat',
    );
    return isAIChatOrder ? 'ai_chat' : 'app';
  }
}
