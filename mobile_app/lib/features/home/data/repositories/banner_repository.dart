
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/home/data/models/banner_model.dart';

class BannerRepo {
  final FirebaseFirestore _firestore;

  BannerRepo({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<BannerModel>> streamBanners() {
    int limit = 20;
    return _firestore
        .collection('banner')
        .orderBy('queuePosition', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return BannerModel.fromMap(map: doc.data(), documentId: doc.id);
          }).where((banner) => banner.isActive).toList();
        });
  }

  Future<List<BannerModel>> getBanners({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('banner')
        .orderBy('queuePosition', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => BannerModel.fromMap(map: doc.data(), documentId: doc.id))
        .where((banner) => banner.isActive)
        .toList();
  }

  Stream<BannerModel?> streamBannerById(String id) {
    return _firestore.collection('banner').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;

      return BannerModel.fromMap(map: doc.data()!, documentId: doc.id);
    });
  }
}
