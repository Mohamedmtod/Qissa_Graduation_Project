import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/wishlist/data/models/wishlist_item_model.dart';
import 'dart:developer';

class WishlistRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleWishlist(String uid, WishlistItemModel item) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('wishlist')
          .doc(item.productId);

      final docSnap = await docRef.get();

      if (docSnap.exists) {
        await docRef.delete();
      } else {
        await docRef.set(item.toMap());
      }
    } catch (e) {
      log('Error toggling wishlist: $e');
      throw Exception('Failed to update wishlist');
    }
  }

  Stream<List<WishlistItemModel>> streamWishlist(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WishlistItemModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<bool> isProductInWishlist(String uid, String productId) async {
    try {
      final docSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('wishlist')
          .doc(productId)
          .get();
      return docSnap.exists;
    } catch (e) {
      log('Error checking wishlist: $e');
      return false;
    }
  }
}
