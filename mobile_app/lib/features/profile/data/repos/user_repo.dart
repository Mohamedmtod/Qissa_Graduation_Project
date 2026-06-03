import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'dart:developer';

class UserRepo {
  final FirebaseFirestore _firestore;

  UserRepo({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch user data once
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      log('Error getting user: $e');
      rethrow;
    }
  }

  /// Listen to user data changes in real-time
  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  /// Update user profile data
  Future<void> updateUser(UserModel user) async {
    try {
      final updatedData = user.toMap();
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updatedData, SetOptions(merge: true));

      log('User updated successfully: ${user.uid}');
    } catch (e) {
      log('Error updating user: $e');
      rethrow;
    }
  }

  /// Update only the preferred payment method for the user
  Future<void> updatePreferredPaymentMethod({
    required String uid,
    required String? preferredPaymentMethod,
  }) async {
    try {
      final validatedPreferredPaymentMethod =
          PaymentMethodCodes.requireSupportedPreference(preferredPaymentMethod);

      await _firestore.collection('users').doc(uid).set({
        'preferredPaymentMethod': validatedPreferredPaymentMethod,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log('Preferred payment method updated successfully: $uid');
    } catch (e) {
      log('Error updating preferred payment method: $e');
      rethrow;
    }
  }
}
