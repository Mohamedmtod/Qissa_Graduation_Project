import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/composite_recipe.dart';

class AdminRecipeService {
  final FirebaseFirestore _firestore;

  AdminRecipeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CompositeRecipe>> fetchRecipes() async {
    final snapshot = await _firestore.collection('recipes').get();
    return snapshot.docs
        .map((doc) => CompositeRecipe.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  Future<CompositeRecipe?> getRecipeForProduct(String productId) async {
    final snapshot = await _firestore
        .collection('recipes')
        .where('productId', isEqualTo: productId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return CompositeRecipe.fromJson({
      'id': doc.id,
      ...doc.data(),
    });
  }

  Future<void> saveRecipe(CompositeRecipe recipe) async {
    final docRef = _firestore.collection('recipes').doc(recipe.id.isEmpty ? null : recipe.id);
    final data = recipe.toJson();
    data['updatedAt'] = DateTime.now().toIso8601String();
    if (recipe.id.isEmpty) {
      data['createdAt'] = DateTime.now().toIso8601String();
      await docRef.set(data);
    } else {
      await docRef.set(data, SetOptions(merge: true));
    }
  }
}
