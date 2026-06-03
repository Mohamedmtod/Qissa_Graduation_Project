import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/features/products/data/models/frequent_recommendation_model.dart';

class FrequentRecommendationRepo {
  final FirebaseFirestore _firestore;

  FrequentRecommendationRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<FrequentRecommendationModel?> fetchByTriggerProductId(
    String productId,
  ) async {
    final trimmedId = productId.trim();
    if (trimmedId.isEmpty) return null;

    final doc = await _firestore
        .collection('frequent_recommendations')
        .doc(trimmedId)
        .get();

    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }

    return FrequentRecommendationModel.fromMap(data);
  }
}
