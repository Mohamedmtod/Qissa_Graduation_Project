import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';

// States
abstract class AddToCartState {}

class AddToCartInitial extends AddToCartState {}

class AddToCartLoading extends AddToCartState {}

class AddToCartSuccess extends AddToCartState {}

class AddToCartError extends AddToCartState {
  final String message;
  AddToCartError(this.message);
}

// Cubit
class AddToCartCubit extends Cubit<AddToCartState> {
  final CartRepo cartRepo;
  final EventRepo eventRepo;
  final UserTasteRepo? userTasteRepo;

  AddToCartCubit({
    required this.cartRepo,
    required this.eventRepo,
    this.userTasteRepo,
  }) : super(AddToCartInitial());

  Future<void> addToCart({
    required String uid,
    required CartItemModel item,
    required int currentStock,
  }) async {
    log('[AddToCartCubit] addToCart called: uid=$uid, productId=${item.productId}, stock=$currentStock, qty=${item.quantity}');
    if (currentStock < item.quantity) {
      log('[AddToCartCubit] ERROR: Not enough stock');
      emit(AddToCartError("Not enough stock available"));
      return;
    }

    emit(AddToCartLoading());
    try {
      await cartRepo.addToCart(uid, item, maxStock: currentStock);
      log('[AddToCartCubit] SUCCESS: Item added to cart');
      emit(AddToCartSuccess());

      _trackAddToCart(item, uid);
    } catch (e) {
      log('[AddToCartCubit] ERROR: $e');
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      emit(AddToCartError(msg));
    }
  }

  void _trackAddToCart(CartItemModel item, String userId) {
    Future<void>(() async {
      try {
        await eventRepo.logAddToCart(
          productId: item.productId,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
        );
      } catch (_) {
        // Non-blocking analytics.
      }

      try {
        await userTasteRepo?.recordEvent(
          eventType: EventType.addToCart,
          notes: item.notes,
          userId: userId,
        );
      } catch (_) {
        // Non-blocking local tracking.
      }
    });
  }
}
