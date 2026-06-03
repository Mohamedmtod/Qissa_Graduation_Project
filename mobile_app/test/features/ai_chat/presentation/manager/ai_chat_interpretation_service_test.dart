import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_interpretation_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_interpretation_service.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

AIChatTurnContext _incoming(String message) {
  return AIChatTurnContext(
    trimmed: message,
    activeSessionId: 'session',
    responseLanguage: AIChatLanguage.english,
    effectiveRecommendationMemory: const RecommendationMemory(),
    intent: LocalIntentParser.detectIntent(message),
    shouldContinueAvailabilityClarification: false,
    isGreetingOnly: false,
    requestId: 'request',
  );
}

AIChatTurnDecision _clarifyDecision() {
  return const AIChatTurnDecision(
    route: AIChatTurnDecisionRoute.clarify,
    confidence: AIChatTurnDecisionConfidence.medium,
    reasonCode: 'ambiguous_standalone_latin_phrase',
    shouldAllowAvailability: false,
  );
}

ProductModel _product() {
  final now = Timestamp.now();
  return ProductModel(
    id: 'sauvage',
    name: 'Dior Sauvage',
    nameLower: 'dior sauvage',
    searchPrefixes: const [],
    brand: 'Dior',
    price: 4650,
    stock: 4,
    gender: 'men',
    season: 'all_seasons',
    fragranceFamily: 'aromatic',
    notes: const ['cedar', 'bergamot'],
    imageUrls: const [],
    description: '',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'all_day',
    intensity: 'strong',
    topNotes: const [],
    middleNotes: const [],
    baseNotes: const [],
    tags: const ['fresh'],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const SessionPreferences());
    registerFallbackValue(AIChatLanguage.english);
  });

  setUp(() {
    AIChatExperimentConfig.setTestOverrides(llmLedRouterV2: false);
  });

  tearDown(AIChatExperimentConfig.resetTestOverrides);

  group('AIChatInterpretationService availability validation', () {
    late _MockAIChatRepo repo;
    late AIChatInterpretationService service;

    setUp(() {
      repo = _MockAIChatRepo();
      service = AIChatInterpretationService(aiChatRepo: repo);
    });

    test('rejects AI availability when candidate is generic', () async {
      when(
        () => repo.fetchAIInterpretation(
          currentMessage: any(named: 'currentMessage'),
          currentPreferences: any(named: 'currentPreferences'),
          responseLanguage: any(named: 'responseLanguage'),
          hasRecommendationContext: any(named: 'hasRecommendationContext'),
          hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async => AIChatInterpretationResult.fromJson({
          'intent': 'availability',
          'confidence': 0.91,
          'productQueryCandidate': 'perfume',
          'preferencePatch': {},
          'askSlot': null,
          'reasonCode': 'model_generic',
        }),
      );

      final result = await service.interpretIfUseful(
        incoming: _incoming('do you have perfume?'),
        turnDecision: _clarifyDecision(),
        state: const AIChatState(),
        catalog: [_product()],
      );

      expect(result, isNull);
    });

    test('rejects low-confidence AI availability', () async {
      when(
        () => repo.fetchAIInterpretation(
          currentMessage: any(named: 'currentMessage'),
          currentPreferences: any(named: 'currentPreferences'),
          responseLanguage: any(named: 'responseLanguage'),
          hasRecommendationContext: any(named: 'hasRecommendationContext'),
          hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async => AIChatInterpretationResult.fromJson({
          'intent': 'availability',
          'confidence': 0.55,
          'productQueryCandidate': 'Rosendo Mateu',
          'preferencePatch': {},
          'askSlot': null,
          'reasonCode': 'model_low',
        }),
      );

      final result = await service.interpretIfUseful(
        incoming: _incoming('do you have Rosendo Mateu?'),
        turnDecision: _clarifyDecision(),
        state: const AIChatState(),
        catalog: [_product()],
      );

      expect(result, isNull);
    });

    test(
      'accepts high-confidence product-shaped availability candidate',
      () async {
        when(
          () => repo.fetchAIInterpretation(
            currentMessage: any(named: 'currentMessage'),
            currentPreferences: any(named: 'currentPreferences'),
            responseLanguage: any(named: 'responseLanguage'),
            hasRecommendationContext: any(named: 'hasRecommendationContext'),
            hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer(
          (_) async => AIChatInterpretationResult.fromJson({
            'intent': 'availability',
            'confidence': 0.9,
            'productQueryCandidate': 'Rosendo Mateu',
            'preferencePatch': {},
            'askSlot': null,
            'reasonCode': 'model_product_anchor',
          }),
        );

        final result = await service.interpretIfUseful(
          incoming: _incoming('do you have Rosendo Mateu?'),
          turnDecision: _clarifyDecision(),
          state: const AIChatState(),
          catalog: [_product()],
        );

        expect(result, isNotNull);
        expect(result!.incoming.intent, AIChatIntent.availabilityCheck);
        expect(result.incoming.availabilityProductQuery, 'Rosendo Mateu');
      },
    );

    test('skips interpretation for reference cheaper recommendation', () async {
      final result = await service.interpretIfUseful(
        incoming: _incoming(
          'عندك عطر يكون شبه Dior Sauvage بس يكون سعره أرخص منه؟',
        ),
        turnDecision: const AIChatTurnDecision(
          route: AIChatTurnDecisionRoute.recommendation,
          confidence: AIChatTurnDecisionConfidence.high,
          reasonCode: 'reference_cheaper_recommendation',
          shouldAllowAvailability: false,
        ),
        state: const AIChatState(),
        catalog: [_product()],
      );

      expect(result, isNull);
      verifyNever(
        () => repo.fetchAIInterpretation(
          currentMessage: any(named: 'currentMessage'),
          currentPreferences: any(named: 'currentPreferences'),
          responseLanguage: any(named: 'responseLanguage'),
          hasRecommendationContext: any(named: 'hasRecommendationContext'),
          hasAvailabilityContext: any(named: 'hasAvailabilityContext'),
          requestId: any(named: 'requestId'),
        ),
      );
    });
  });
}
