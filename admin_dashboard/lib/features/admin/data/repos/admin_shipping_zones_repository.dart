import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shipping_zone_model.dart';

class AdminShippingZonesRepository {
  AdminShippingZonesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collectionPath = 'config';
  static const String _docPath = 'shipping_zones';

  /// Get all shipping zones from Firestore.
  /// If the document doesn't exist, it returns the default seed data.
  Future<List<ShippingZoneModel>> getShippingZones() async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(_docPath)
          .get();

      if (!doc.exists) {
        // If not exists, return seed data but don't save yet
        // (saving happens when admin first edits)
        return ShippingZoneModel.egyptSeedData;
      }

      final data = doc.data() as Map<String, dynamic>;
      final List<dynamic> zonesList = data['zones'] ?? [];

      return zonesList.map((z) => ShippingZoneModel.fromMap(z)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update the entire list of shipping zones.
  Future<void> updateShippingZones(
    List<ShippingZoneModel> zones, {
    String? traceId,
  }) async {
    try {
      final data = {
        'zones': zones.map((z) => z.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_collectionPath)
          .doc(_docPath)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Seed the database with default values if empty.
  Future<void> seedInitialData() async {
    final doc = await _firestore
        .collection(_collectionPath)
        .doc(_docPath)
        .get();
    if (!doc.exists) {
      await updateShippingZones(ShippingZoneModel.egyptSeedData);
    }
  }
}
