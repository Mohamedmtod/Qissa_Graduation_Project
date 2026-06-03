import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/events/data/models/event_model.dart';

class EventRepo {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EventRepo({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> logSearch(String query) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('events').doc();

    final event = EventModel(
      id: docRef.id,
      userId: user.uid,
      eventType: 'search',
      data: {'query': query},
      timestamp: Timestamp.now(),
    );

    try {
      await docRef.set(event.toMap());
    } catch (e) {
      debugPrint("Failed to log search event: $e");
    }
  }

  Future<void> logProductView({required String productId, required String name, required double price}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('events').doc();
    final event = EventModel(
      id: docRef.id,
      userId: user.uid,
      eventType: 'product_view',
      data: {'productId': productId, 'name': name, 'price': price},
      timestamp: Timestamp.now(),
    );

    try { await docRef.set(event.toMap()); } catch (e) { debugPrint("Failed to log product_view: $e"); }
  }

  Future<void> logAddToCart({required String productId, required String name, required double price, required int quantity}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('events').doc();
    final event = EventModel(
      id: docRef.id,
      userId: user.uid,
      eventType: 'add_to_cart',
      data: {'productId': productId, 'name': name, 'price': price, 'quantity': quantity},
      timestamp: Timestamp.now(),
    );

    try { await docRef.set(event.toMap()); } catch (e) { debugPrint("Failed to log add_to_cart: $e"); }
  }

  Future<void> logOrderRequest({
    required String orderId,
    required double total,
    required int itemCount,
    required List<Map<String, dynamic>> items,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('events').doc();
    final event = EventModel(
      id: docRef.id,
      userId: user.uid,
      eventType: 'order_request_created',
      data: {
        'orderId': orderId,
        'total': total,
        'itemCount': itemCount,
        'items': items,
      },
      timestamp: Timestamp.now(),
    );

    try { await docRef.set(event.toMap()); } catch (e) { debugPrint("Failed to log order_request_created: $e"); }
  }

}
