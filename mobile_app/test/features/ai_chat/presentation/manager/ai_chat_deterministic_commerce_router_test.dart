import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_deterministic_commerce_router.dart';

void main() {
  group('AIChatDeterministicCommerceRouter', () {
    const router = AIChatDeterministicCommerceRouter();

    test('routes accepted budget floor only after budget no-match', () {
      final route = router.resolve(
        message: 'ok show me it',
        memory: const RecommendationMemory(
          lastNoMatchContext: LastNoMatchContext(
            reason: 'budget_no_match',
            requestedBudget: 600,
            lowestAvailablePrice: 790,
            lowestAvailableProductIds: ['p1'],
          ),
        ),
      );

      expect(
        route?.toolName,
        AIChatToolName.showLowestAvailableAfterBudgetNoMatch,
      );
      expect(route?.reasonCode, 'budget_floor_acceptance_followup');
    });

    test('does not route budget floor acceptance without no-match context', () {
      final route = router.resolve(
        message: 'ok show me it',
        memory: const RecommendationMemory(),
      );

      expect(route, isNull);
    });

    test('routes visible rejection with grounded visible product ids', () {
      final route = router.resolve(
        message: "I don't like these",
        memory: RecommendationMemory(
          lastRecommendedProducts: [_ref('p1', 1), _ref('p2', 2)],
        ),
      );

      expect(route?.toolName, AIChatToolName.rejectVisibleProducts);
      expect(route?.reasonCode, 'reject_visible_products_followup');
      expect(route?.arguments['rejectedProductIds'], ['p1', 'p2']);
    });

    test('routes similar cheaper only when an anchor exists', () {
      final route = router.resolve(
        message: 'similar but cheaper',
        memory: const RecommendationMemory(lastFocusedProductId: 'p1'),
      );
      final noAnchorRoute = router.resolve(
        message: 'similar but cheaper',
        memory: const RecommendationMemory(),
      );

      expect(route?.toolName, AIChatToolName.similarCheaper);
      expect(route?.reasonCode, 'similar_cheaper_followup');
      expect(noAnchorRoute, isNull);
    });

    test('routes cheaper follow-up from visible recommendation context', () {
      final route = router.resolve(
        message: 'anything cheaper?',
        memory: RecommendationMemory(lastRecommendedProducts: [_ref('p1', 1)]),
      );

      expect(route?.toolName, AIChatToolName.cheaperFollowup);
      expect(route?.reasonCode, 'cheaper_followup');
    });

    test('does not guess it anchor from visible cards only', () {
      final route = router.resolve(
        message: 'cheaper than it',
        memory: RecommendationMemory(lastRecommendedProducts: [_ref('p1', 1)]),
      );

      expect(route, isNull);
    });

    test('routes cheaper than it to last external profile anchor', () {
      final route = router.resolve(
        message: 'cheaper than it',
        memory: RecommendationMemory(
          lastExternalProfile: const ExternalProfileRef(
            id: 'dior_sauvage',
            name: 'Dior Sauvage',
            priceReference: 5000,
          ),
          lastRecommendedProducts: [_ref('p1', 1)],
        ),
      );

      expect(route?.toolName, AIChatToolName.similarCheaperToExternalProfile);
      expect(route?.reasonCode, 'external_profile_cheaper_followup');
      expect(route?.arguments['externalProfileId'], 'dior_sauvage');
    });
  });
}

RecommendedProductRef _ref(String productId, int index) {
  return RecommendedProductRef(
    productId: productId,
    name: 'Product $index',
    brand: 'Brand',
    displayIndex: index,
    price: 1000.0 + index,
    stock: 1,
    season: 'summer',
    occasion: 'daily',
    intensity: 'light',
    notes: const ['fresh'],
  );
}
