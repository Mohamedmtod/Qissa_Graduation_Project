import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestockNotificationRepo {
  RestockNotificationRepo({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DateTime Function()? now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  Future<bool> isRequested({
    required String userId,
    required String productId,
  }) async {
    log(
      'Checking existing notify request | userId=$userId productId=$productId',
      name: 'RestockNotificationRepo',
    );
    final doc = await _requestDoc(userId: userId, productId: productId).get();
    final data = doc.data();
    if (data == null) {
      log(
        'No existing notify request | userId=$userId productId=$productId',
        name: 'RestockNotificationRepo',
      );
      return false;
    }
    final status = data['status']?.toString().trim().toLowerCase();
    final requested = status == 'pending' || status == 'notified';
    log(
      'Existing notify request status=$status requested=$requested | userId=$userId productId=$productId',
      name: 'RestockNotificationRepo',
    );
    return requested;
  }

  Future<void> requestNotification({
    required String userId,
    required String productId,
  }) async {
    log(
      'Notify request save started | userId=$userId productId=$productId',
      name: 'RestockNotificationRepo',
    );
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      log(
        'Notify request blocked: unauthenticated or mismatched user | userId=$userId productId=$productId currentUser=${user?.uid}',
        name: 'RestockNotificationRepo',
      );
      throw StateError('User is not authenticated for restock request.');
    }

    final productSnapshot = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    if (!productSnapshot.exists) {
      log(
        'Notify request blocked: product does not exist | userId=$userId productId=$productId',
        name: 'RestockNotificationRepo',
      );
      throw StateError('Product is not available for restock notification.');
    }

    final doc = _requestDoc(userId: userId, productId: productId);

    final email = user.email?.trim() ?? '';
    final phone = user.phoneNumber?.trim() ?? '';
    final contactMethod = email.isNotEmpty
        ? 'email'
        : phone.isNotEmpty
        ? 'phone'
        : null;
    final contactValue = email.isNotEmpty ? email : phone;
    if (contactMethod == null || contactValue.isEmpty) {
      log(
        'Notify request blocked: missing contact value | userId=$userId productId=$productId',
        name: 'RestockNotificationRepo',
      );
      throw StateError(
        'Authenticated contact information is required for restock requests.',
      );
    }

    final now = Timestamp.fromDate(_now());
    final payload = <String, dynamic>{
      'id': doc.id,
      'productId': productId,
      'userId': userId,
      'contactMethod': contactMethod,
      'contactValue': contactValue,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    };
    log(
      'Notify request payload prepared | docId=${doc.id} keys=${payload.keys.join(',')} contactMethod=$contactMethod',
      name: 'RestockNotificationRepo',
    );
    try {
      await doc.set(payload);
      log(
        'Notify request saved | docId=${doc.id} userId=$userId productId=$productId contactMethod=$contactMethod',
        name: 'RestockNotificationRepo',
      );
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') {
        final activeStatus = await _activeExistingRequestStatus(
          doc: doc,
          userId: userId,
          productId: productId,
        );
        if (activeStatus != null) {
          log(
            'Notify request already exists; treating as saved | docId=${doc.id} status=$activeStatus userId=$userId productId=$productId',
            name: 'RestockNotificationRepo',
          );
          return;
        }
      }
      log(
        'Notify request save failed | docId=${doc.id} userId=$userId productId=$productId code=${e.code}',
        name: 'RestockNotificationRepo',
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      log(
        'Notify request save failed | docId=${doc.id} userId=$userId productId=$productId',
        name: 'RestockNotificationRepo',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  DocumentReference<Map<String, dynamic>> _requestDoc({
    required String userId,
    required String productId,
  }) {
    return _firestore
        .collection('restock_requests')
        .doc('${userId}_$productId');
  }

  Future<String?> _activeExistingRequestStatus({
    required DocumentReference<Map<String, dynamic>> doc,
    required String userId,
    required String productId,
  }) async {
    try {
      final existing = await doc.get();
      final data = existing.data();
      if (data == null) {
        return null;
      }

      final existingUserId = data['userId']?.toString().trim();
      if (existingUserId != userId) {
        log(
          'Existing notify request ignored: owner mismatch | docId=${doc.id} expectedUserId=$userId actualUserId=$existingUserId productId=$productId',
          name: 'RestockNotificationRepo',
        );
        return null;
      }

      final status = data['status']?.toString().trim().toLowerCase();
      if (status == 'pending' || status == 'notified') {
        return status;
      }

      log(
        'Existing notify request is not active | docId=${doc.id} status=$status userId=$userId productId=$productId',
        name: 'RestockNotificationRepo',
      );
      return null;
    } on FirebaseException catch (e, st) {
      log(
        'Existing notify request lookup failed | docId=${doc.id} userId=$userId productId=$productId code=${e.code}',
        name: 'RestockNotificationRepo',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
