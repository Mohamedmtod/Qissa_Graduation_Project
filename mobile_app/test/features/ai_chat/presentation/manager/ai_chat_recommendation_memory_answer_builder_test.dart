import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_recommendation_memory_answer_builder.dart';

void main() {
  const builder = AIChatRecommendationMemoryAnswerBuilder();
  const first = RecommendedProductRef(
    productId: 'p1',
    name: 'Light Blue',
    brand: 'Dolce & Gabbana',
    displayIndex: 1,
    price: 3250,
    stock: 10,
    season: 'summer',
    occasion: 'office',
    intensity: 'medium',
    notes: ['citrus', 'musk'],
    matchReason: 'Matches fruity notes. Suitability: office mismatch.',
  );
  const second = RecommendedProductRef(
    productId: 'p2',
    name: 'Acqua di Gio',
    brand: 'Giorgio Armani',
    displayIndex: 2,
    price: 3350,
    stock: 10,
    season: 'summer',
    occasion: 'office',
    intensity: 'strong',
    notes: ['aquatic'],
  );

  test('builds selection answer with cart guidance', () {
    final answer = builder.buildSelectionAnswer(
      const [first],
      AIChatLanguage.english,
      wantsCart: true,
    );

    expect(answer, contains('Light Blue'));
    expect(answer, contains('Details'));
    expect(answer, contains('Add to cart'));
  });

  test('cleans internal suitability text from memory reason', () {
    final answer = builder.buildMemoryAnswer(
      first,
      AIChatLanguage.english,
      includeNotes: true,
      includeReason: true,
    );

    expect(answer, contains('Main notes: citrus, musk'));
    expect(answer, contains('Matches fruity notes'));
    expect(answer, isNot(contains('Suitability:')));
  });

  test('builds cheapest visible answer', () {
    final answer = builder.buildCheapestAnswer(const [
      first,
      second,
    ], AIChatLanguage.english);

    expect(answer, contains('Light Blue'));
    expect(answer, contains('3250 EGP'));
  });

  test('builds comparison answer', () {
    final answer = builder.buildComparisonAnswer(const [
      first,
      second,
    ], AIChatLanguage.english);

    expect(answer, contains('Light Blue is lighter than Acqua di Gio'));
  });
}
