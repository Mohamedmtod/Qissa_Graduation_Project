import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_selection_resolver.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

void main() {
  const resolver = AIChatRecommendationSelectionResolver();
  const refs = [
    RecommendedProductRef(
      productId: 'p1',
      name: 'Light Blue',
      brand: 'Dolce & Gabbana',
      displayIndex: 1,
      price: 3250,
      stock: 10,
      season: 'summer',
      occasion: 'office',
      intensity: 'medium',
      notes: ['citrus'],
    ),
    RecommendedProductRef(
      productId: 'p2',
      name: 'Acqua di Gio',
      brand: 'Giorgio Armani',
      displayIndex: 2,
      price: 3350,
      stock: 10,
      season: 'summer',
      occasion: 'office',
      intensity: 'medium',
      notes: ['aquatic'],
    ),
    RecommendedProductRef(
      productId: 'p3',
      name: 'Si',
      brand: 'Giorgio Armani',
      displayIndex: 3,
      price: 3350,
      stock: 10,
      season: 'autumn',
      occasion: 'daily',
      intensity: 'medium',
      notes: ['floral'],
    ),
  ];

  test('resolves ordinal product selection', () {
    final result = resolver.resolve(
      LocalIntentParser.normalizeInput('the second one'),
      refs,
    );

    expect(result, isNotNull);
    expect(result!.matches.single.productId, 'p2');
  });

  test('resolves first two selection', () {
    final result = resolver.resolve(
      LocalIntentParser.normalizeInput('first two'),
      refs,
    );

    expect(result, isNotNull);
    expect(result!.matches.map((ref) => ref.productId), ['p1', 'p2']);
  });

  test('allows exact name when requested', () {
    final result = resolver.resolve(
      LocalIntentParser.normalizeInput('Light Blue'),
      refs,
      allowNameOnly: true,
    );

    expect(result, isNotNull);
    expect(result!.matches.single.productId, 'p1');
  });

  test('does not resolve name-only without explicit permission', () {
    final result = resolver.resolve(
      LocalIntentParser.normalizeInput('Light Blue'),
      refs,
    );

    expect(result, isNull);
  });

  test('resolves Arabic ordinal fixtures', () {
    final normalized = LocalIntentParser.normalizeInput(
      '\u0627\u0644\u0623\u0648\u0644',
    );
    final result = resolver.resolve(normalized, refs);

    expect(result, isNotNull);
    expect(result!.matches.single.productId, 'p1');
  });
}
