import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_no_match_builder.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  group('buildNoMatchMessage', () {
    test('uses budget-specific copy', () {
      final message = buildNoMatchMessage(
        'under 100',
        const SessionPreferences(maxBudget: 100),
        const [],
        AIChatLanguage.english,
        reasonCode: 'budget_no_match',
      );

      expect(message.toLowerCase(), contains('budget'));
    });

    test('budget below catalog minimum mentions minimum price', () {
      final message = buildNoMatchMessage(
        'under 100',
        const SessionPreferences(maxBudget: 100),
        [_product(price: 790)],
        AIChatLanguage.english,
        reasonCode: 'budget_no_match',
      );

      expect(message, contains('100'));
      expect(message, contains('790'));
    });

    test('uses excluded-note-specific copy', () {
      final message = buildNoMatchMessage(
        'without oud',
        const SessionPreferences(excludedNotes: ['oud']),
        const [],
        AIChatLanguage.english,
        reasonCode: 'excluded_note_no_match',
      );

      expect(message.toLowerCase(), contains('excluding oud'));
    });

    test('external known no substitute asks for scent direction', () {
      final message = buildNoMatchMessage(
        'Sauvage',
        const SessionPreferences(),
        const [],
        AIChatLanguage.english,
        reasonCode: 'external_known_no_substitute',
      );

      expect(message.toLowerCase(), contains('not available'));
      expect(message.toLowerCase(), contains('freshness'));
    });

    test('uses strong-scent-specific copy', () {
      final message = buildNoMatchMessage(
        'vanilla citrus',
        const SessionPreferences(preferredNotes: ['vanilla', 'citrus']),
        const [],
        AIChatLanguage.english,
        reasonCode: 'strong_scent_no_match',
      );

      expect(message.toLowerCase(), contains('scent direction'));
    });
  });
}

ProductModel _product({required double price}) {
  final now = Timestamp.now();
  return ProductModel(
    id: 'p-$price',
    name: 'Test Perfume',
    nameLower: 'test perfume',
    searchPrefixes: const ['test'],
    brand: 'Brand',
    price: price,
    stock: 1,
    gender: 'unisex',
    season: 'all_seasons',
    fragranceFamily: 'fresh',
    notes: const ['fresh'],
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const [],
    imageUrls: const ['https://example.com/p.png'],
    description: 'Test',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'day',
    intensity: 'medium',
  );
}
