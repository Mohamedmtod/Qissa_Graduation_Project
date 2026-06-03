import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/recommendation_reference_resolver.dart';

RecommendationMemory _memory({String? focusedProductId}) {
  return RecommendationMemory(
    lastRecommendedProducts: const [
      RecommendedProductRef(
        productId: 'p1',
        name: 'Asad',
        brand: 'Lattafa',
        displayIndex: 1,
        price: 1200,
        stock: 10,
        season: 'winter',
        occasion: 'evening',
        intensity: 'strong',
        notes: ['oud'],
      ),
      RecommendedProductRef(
        productId: 'p2',
        name: 'Yara',
        brand: 'Lattafa',
        displayIndex: 2,
        price: 900,
        stock: 7,
        season: 'summer',
        occasion: 'daily',
        intensity: 'medium',
        notes: ['vanilla'],
      ),
      RecommendedProductRef(
        productId: 'p3',
        name: 'Hawas',
        brand: 'Rasasi',
        displayIndex: 3,
        price: 1500,
        stock: 4,
        season: 'all_seasons',
        occasion: 'daily',
        intensity: 'strong',
        notes: ['fresh'],
      ),
    ],
    lastFocusedProductId: focusedProductId,
    lastRecommendationBatchId: 'batch-1',
  );
}

void main() {
  group('RecommendationReferenceResolver', () {
    test('resolves multiple ordered products in one message', () {
      final resolved = RecommendationReferenceResolver.resolve(
        message: 'Compare first and second',
        memory: _memory(),
      );

      final ids = resolved.map((item) => item.productId).toSet();
      expect(ids, {'p1', 'p2'});
    });

    test('resolves numeric product references in English and Arabic', () {
      final englishResolved = RecommendationReferenceResolver.resolve(
        message: 'Compare 2 and 3',
        memory: _memory(),
      );
      final arabicResolved = RecommendationReferenceResolver.resolve(
        message: 'قارن بين ٢ و٣',
        memory: _memory(),
      );

      expect(englishResolved.map((item) => item.productId).toSet(), {
        'p2',
        'p3',
      });
      expect(arabicResolved.map((item) => item.productId).toSet(), {
        'p2',
        'p3',
      });
    });

    test('resolves numeric product references with Persian digits too', () {
      final persianResolved = RecommendationReferenceResolver.resolve(
        message: 'قارن بين ۲ و۳',
        memory: _memory(),
      );

      expect(persianResolved.map((item) => item.productId).toSet(), {
        'p2',
        'p3',
      });
    });

    test('resolves product by explicit name', () {
      final resolved = RecommendationReferenceResolver.resolve(
        message: 'Tell me more about Yara',
        memory: _memory(),
      );

      expect(resolved, isNotEmpty);
      expect(resolved.first.productId, 'p2');
    });

    test('does not treat "with" as pronoun match for "it"', () {
      final resolved = RecommendationReferenceResolver.resolve(
        message: 'I want something with vanilla',
        memory: _memory(focusedProductId: 'p1'),
      );

      expect(resolved, isEmpty);
    });

    test('resolves pronoun when it is standalone and focused exists', () {
      final resolved = RecommendationReferenceResolver.resolve(
        message: 'Tell me more about it.',
        memory: _memory(focusedProductId: 'p3'),
      );

      expect(resolved, hasLength(1));
      expect(resolved.first.productId, 'p3');
    });
  });
}
