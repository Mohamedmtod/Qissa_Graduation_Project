import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'dart:async';
import 'dart:developer';

class CartRepo {
  static const String guestCartUserId = '__guest_cart__';

  final FirebaseFirestore _firestore;
  final Map<String, CartItemModel> _guestItems = <String, CartItemModel>{};
  final StreamController<List<CartItemModel>> _guestCartController =
      StreamController<List<CartItemModel>>.broadcast();

  CartRepo({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> addToCart(
    String uid,
    CartItemModel item, {
    int? maxStock,
  }) async {
    if (uid == guestCartUserId) {
      _addToGuestCart(item, maxStock: maxStock);
      return;
    }

    try {
      final cartRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('cart');
      final docRef = cartRef.doc(item.cartDocumentId);

      await _firestore.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);

        if (docSnap.exists) {
          // Update quantity if item exists
          final currentQty = docSnap.data()?['quantity'] as int? ?? 0;
          final newQty = currentQty + item.quantity;

          if (maxStock != null && newQty > maxStock) {
            throw Exception('Only $maxStock items available in stock');
          }

          transaction.update(docRef, {
            'quantity': newQty,
            // Update price/image in case they changed (optional, but good for data consistency)
            'price': item.price,
            'imageUrl': item.imageUrl,
            'notes': item.notes,
            'variantId': item.variantId,
            if (item.variantLabel.trim().isNotEmpty)
              'variantLabel': item.variantLabel,
          });
        } else {
          if (maxStock != null && item.quantity > maxStock) {
            throw Exception('Only $maxStock items available in stock');
          }
          // Add new item
          transaction.set(docRef, item.toMap());
        }
      });
    } catch (e) {
      log('Error adding to cart: $e');
      rethrow;
    }
  }

  // Stream cart items
  Stream<List<CartItemModel>> streamCart(String uid) {
    if (uid == guestCartUserId) {
      return Stream<List<CartItemModel>>.multi((controller) {
        controller.add(List<CartItemModel>.from(_guestItems.values));
        final subscription = _guestCartController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      });
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cart')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CartItemModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> removeFromCart(String uid, String itemId) async {
    if (uid == guestCartUserId) {
      _guestItems.remove(itemId);
      _emitGuestCart();
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(itemId)
          .delete();
    } catch (e) {
      log('Error removing from cart: $e');
      throw Exception('Failed to remove item from cart');
    }
  }

  Future<void> updateQuantity(String uid, String itemId, int quantity) async {
    if (uid == guestCartUserId) {
      final item = _guestItems[itemId];
      if (item == null) return;
      if (quantity <= 0) {
        _guestItems.remove(itemId);
      } else {
        _guestItems[itemId] = item.copyWith(quantity: quantity);
      }
      _emitGuestCart();
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(itemId)
          .update({'quantity': quantity});
    } catch (e) {
      log('Error updating cart quantity: $e');
      throw Exception('Failed to update cart quantity');
    }
  }

  Future<void> clearCart(String uid) async {
    if (uid == guestCartUserId) {
      _guestItems.clear();
      _emitGuestCart();
      return;
    }

    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('cart')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      log('Error clearing cart: $e');
      throw Exception('Failed to clear cart');
    }
  }

  Future<void> mergeGuestCartIntoUser(String uid) async {
    if (_guestItems.isEmpty) return;

    try {
      final cartRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('cart');

      final cartSnap = await cartRef.get();
      final existingDocIds = cartSnap.docs.map((doc) => doc.id).toSet();

      final batch = _firestore.batch();
      final guestItemsList = List<CartItemModel>.from(_guestItems.values);

      for (final item in guestItemsList) {
        final docRef = cartRef.doc(item.cartDocumentId);
        if (existingDocIds.contains(item.cartDocumentId)) {
          final userItemDoc = cartSnap.docs.firstWhere((doc) => doc.id == item.cartDocumentId);
          final currentQty = userItemDoc.data()['quantity'] as int? ?? 0;
          batch.update(docRef, {'quantity': currentQty + item.quantity});
        } else {
          batch.set(docRef, item.toMap());
        }
      }

      await batch.commit();
      _guestItems.clear();
      _emitGuestCart();
    } catch (e) {
      log('Error merging guest cart: $e');
      rethrow;
    }
  }

  void _addToGuestCart(CartItemModel item, {int? maxStock}) {
    final existing = _guestItems[item.cartDocumentId];
    final nextQuantity = (existing?.quantity ?? 0) + item.quantity;
    if (maxStock != null && nextQuantity > maxStock) {
      throw Exception('Only $maxStock items available in stock');
    }
    _guestItems[item.cartDocumentId] = item.copyWith(quantity: nextQuantity);
    _emitGuestCart();
  }

  void _emitGuestCart() {
    if (_guestCartController.isClosed) return;
    _guestCartController.add(List<CartItemModel>.from(_guestItems.values));
  }
}
