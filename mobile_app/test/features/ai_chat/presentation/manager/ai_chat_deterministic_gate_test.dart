import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_deterministic_gate.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

void main() {
  const gate = AIChatDeterministicGate();

  group('AIChatDeterministicGate', () {
    test('routes social turns to needs_llm without confidence scoring', () {
      final decision = gate.evaluate(
        message: 'how are you',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, AIChatDeterministicGateResult.needsLlm);
      expect(
        decision.proofLevel,
        AIChatDeterministicGateProofLevel.insufficient,
      );
      expect(decision.wouldSendToLlm, isTrue);
      expect(decision.proofReasons, isEmpty);
    });

    test('marks exact catalog availability as local safe', () {
      final decision = gate.evaluate(
        message: 'Do you have Light Blue?',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, AIChatDeterministicGateResult.localSafe);
      expect(decision.route, 'exact_catalog_availability');
      expect(
        decision.proofLevel,
        AIChatDeterministicGateProofLevel.deterministic,
      );
      expect(decision.shouldRenderCards, isTrue);
      expect(decision.proofReasons, contains('single_exact_catalog_match'));
    });

    test('marks deterministic visible cheapest question as local safe', () {
      final decision = gate.evaluate(
        message: 'which is cheapest among them?',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: RecommendationMemory(
          lastRecommendedProducts: [_ref('p1', 1, 1200), _ref('p2', 2, 900)],
        ),
      );

      expect(decision.result, AIChatDeterministicGateResult.localSafe);
      expect(decision.route, 'deterministic_visible_product_question');
      expect(decision.proofReasons, contains('deterministic_price_property'));
      expect(decision.shouldRenderCards, isFalse);
    });

    test('does not local-safe subjective visible comparison', () {
      final decision = gate.evaluate(
        message: 'which one is better?',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: RecommendationMemory(
          lastRecommendedProducts: [_ref('p1', 1, 1200), _ref('p2', 2, 900)],
        ),
      );

      expect(decision.result, AIChatDeterministicGateResult.needsLlm);
      expect(
        decision.proofLevel,
        AIChatDeterministicGateProofLevel.insufficient,
      );
      expect(
        decision.ambiguityReasons,
        contains('subjective_visible_product_question'),
      );
    });

    test('marks direct catalog ranking query as local safe', () {
      final decision = gate.evaluate(
        message: 'most expensive perfume',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, AIChatDeterministicGateResult.localSafe);
      expect(decision.route, 'direct_catalog_query');
      expect(decision.proofReasons, contains('direct_catalog_query'));
    });

    test('does not local-safe relative cheaper follow-ups', () {
      for (final message in [
        'show me something cheaper',
        'anything cheaper?',
        'similar but cheaper',
        'cheaper than it',
      ]) {
        final decision = gate.evaluate(
          message: message,
          language: AIChatLanguage.english,
          catalog: _catalog(),
          memory: RecommendationMemory(
            lastRecommendedProducts: [_ref('p1', 1, 1200), _ref('p2', 2, 900)],
          ),
        );

        expect(
          decision.result,
          AIChatDeterministicGateResult.needsLlm,
          reason: message,
        );
        expect(
          decision.ambiguityReasons,
          contains('relative_recommendation_followup'),
          reason: message,
        );
      }
    });

    test('asks clarification for ambiguous Egyptian sweet wording', () {
      final decision = gate.evaluate(
        message:
            '\u0631\u0634\u062d\u0644\u064a \u0631\u064a\u062d\u0629 \u062d\u0644\u0648\u0629',
        language: AIChatLanguage.arabic,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, AIChatDeterministicGateResult.needsClarification);
      expect(decision.route, 'ambiguous_egyptian_sweet');
      expect(decision.ambiguityReasons, contains('sweet_vs_beautiful_meaning'));
    });

    test('does not ask sweet clarification when sweet meaning is explicit', () {
      final decision = gate.evaluate(
        message:
            '\u0639\u0627\u064a\u0632 \u0631\u064a\u062d\u0629 \u062d\u0644\u0648\u0629 \u0645\u0633\u0643\u0631\u0629',
        language: AIChatLanguage.arabic,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.route, isNot('ambiguous_egyptian_sweet'));
      expect(decision.result, AIChatDeterministicGateResult.needsLlm);
    });

    test('asks clarification for short ambiguous catalog reference', () {
      final decision = gate.evaluate(
        message: 'Blue',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, AIChatDeterministicGateResult.needsClarification);
      expect(decision.route, 'ambiguous_product_reference');
      expect(
        decision.proofReasons,
        contains('multiple_catalog_reference_matches'),
      );
    });

    test('does not local-safe short reference without deterministic proof', () {
      final decision = gate.evaluate(
        message: 'Amber',
        language: AIChatLanguage.english,
        catalog: _catalog(),
        memory: const RecommendationMemory(),
      );

      expect(decision.result, isNot(AIChatDeterministicGateResult.localSafe));
    });
  });
}

List<ProductModel> _catalog() {
  return [
    _product(id: 'light_blue', name: 'Light Blue', brand: 'Dolce'),
    _product(id: 'blue_mist', name: 'Blue Mist', brand: 'Qissa'),
    _product(id: 'amber_night', name: 'Amber Night', brand: 'Qissa'),
  ];
}

ProductModel _product({
  required String id,
  required String name,
  required String brand,
}) {
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: const [],
    brand: brand,
    price: 1000,
    stock: 10,
    gender: 'unisex',
    season: 'all_seasons',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const [],
    description: '',
    categoryName: 'Perfumes',
    createdAt: Timestamp(0, 0),
    updatedAt: Timestamp(0, 0),
    occasion: 'daily',
    time: 'day',
    intensity: 'medium',
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const [],
  );
}

RecommendedProductRef _ref(String id, int index, double price) {
  return RecommendedProductRef(
    productId: id,
    name: id,
    brand: 'Qissa',
    displayIndex: index,
    price: price,
    stock: 5,
    season: 'all_seasons',
    occasion: 'daily',
    intensity: 'medium',
    notes: const [],
  );
}
