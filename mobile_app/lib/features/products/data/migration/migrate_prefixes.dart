import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

/// One-time migration: adds `searchPrefixes` and `nameLower` to all
/// existing product documents in Firestore.
///
/// Call this ONCE, then remove or disable it.
/// Usage: await migrateProductPrefixes();
Future<void> migrateProductPrefixes() async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore.collection('products').get();

  debugPrint('🔄 Migrating ${snapshot.docs.length} products...');

  // Firestore batch limit is 500
  final batches = <WriteBatch>[];
  WriteBatch currentBatch = firestore.batch();
  int count = 0;

  for (final doc in snapshot.docs) {
    final name = doc.data()['name'] ?? '';
    final prefixes = buildSearchPrefixes(name);

    currentBatch.update(doc.reference, {
      'nameLower': name.toString().toLowerCase(),
      'searchPrefixes': prefixes,
    });

    count++;
    if (count % 500 == 0) {
      batches.add(currentBatch);
      currentBatch = firestore.batch();
    }
  }

  // Add the last batch if it has remaining items
  if (count % 500 != 0) {
    batches.add(currentBatch);
  }

  // Commit all batches
  for (int i = 0; i < batches.length; i++) {
    await batches[i].commit();
    debugPrint('✅ Batch ${i + 1}/${batches.length} committed');
  }

  debugPrint('🎉 Migration complete! $count products updated.');
}
