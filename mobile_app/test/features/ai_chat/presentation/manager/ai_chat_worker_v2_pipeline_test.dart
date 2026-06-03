import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_structured_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_tool_call.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_budget_policy.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_flow_models.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_handler.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_session_persistence_helper.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_tool_executor.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/final_recommendation_guard.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class _MockAIChatRepo extends Mock implements AIChatRepo {}

ProductModel _product({
  required String id,
  required double price,
  String name = 'Safe Product',
  String gender = 'women',
  String season = 'summer',
  String occasion = 'daily',
  String intensity = 'medium',
  List<String> notes = const ['musk', 'fresh'],
  List<String> topNotes = const ['bergamot'],
  List<String> middleNotes = const ['jasmine'],
  List<String> baseNotes = const ['musk'],
  List<String> tags = const ['fresh'],
  int stock = 5,
  bool isActive = true,
}) {
  final now = Timestamp.fromMillisecondsSinceEpoch(0);
  return ProductModel(
    id: id,
    name: name,
    nameLower: name.toLowerCase(),
    searchPrefixes: buildSearchPrefixes(name),
    brand: 'Brand',
    price: price,
    stock: stock,
    gender: gender,
    season: season,
    fragranceFamily: 'fresh',
    notes: notes,
    imageUrls: const ['https://example.com/p.png'],
    description: 'Fresh safe catalog product.',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    isActive: isActive,
    occasion: occasion,
    time: 'day',
    intensity: intensity,
    topNotes: topNotes,
    middleNotes: middleNotes,
    baseNotes: baseNotes,
    tags: tags,
  );
}

RecommendedProduct _candidate(
  ProductModel product, {
  String reason = 'Safe match.',
  double score = 0.84,
}) {
  return RecommendedProduct(
    product: product,
    matchScore: score,
    matchLabel: 'Great Match',
    matchReason: reason,
  );
}

AIChatStructuredReply _structured(Map<String, dynamic> json) {
  return AIChatStructuredReply.fromJson({
    'schemaVersion': 2,
    'metadata': {
      'requestId': 'pipeline-test',
      'promptVersion': 'chat_v2_structured_commands',
      'provider': 'openrouter',
      'modelId': 'qwen/qwen3-32b',
    },
    ...json,
  });
}

class _PipelineHarness {
  _PipelineHarness({AIChatState? initialState}) {
    state =
        initialState ??
        AIChatState(
          messages: [AIChatMessage.loading()],
          language: AIChatLanguage.english,
        );
    when(() => repo.canPersistSession).thenReturn(false);
    when(
      () => repo.logAIChatEvent(
        eventType: any(named: 'eventType'),
        sessionId: any(named: 'sessionId'),
        userId: any(named: 'userId'),
        metadata: any(named: 'metadata'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.saveAIChatDebugLog(
        phase: any(named: 'phase'),
        sessionId: any(named: 'sessionId'),
        requestId: any(named: 'requestId'),
        language: any(named: 'language'),
        messageText: any(named: 'messageText'),
        detectedIntent: any(named: 'detectedIntent'),
        responseSource: any(named: 'responseSource'),
        issueCode: any(named: 'issueCode'),
        reasonCode: any(named: 'reasonCode'),
        preferencesSnapshot: any(named: 'preferencesSnapshot'),
        availabilityContextSnapshot: any(named: 'availabilityContextSnapshot'),
        recommendationMemorySnapshot: any(
          named: 'recommendationMemorySnapshot',
        ),
        candidateSummary: any(named: 'candidateSummary'),
        recommendedProducts: any(named: 'recommendedProducts'),
        workerReplySummary: any(named: 'workerReplySummary'),
      ),
    ).thenAnswer((_) async {});

    handler = AIChatReplyHandler(
      getState: () => state,
      emitState: (next) => state = next,
      startCooldown: () {},
      onAskQuestion: (question) => lastAskQuestion = question,
      sessionPersistenceHelper: AIChatSessionPersistenceHelper(
        aiChatRepo: repo,
      ),
      aiChatRepo: repo,
      translate: (language, {required ar, required en}) =>
          language.isArabic ? ar : en,
    );
  }

  final _MockAIChatRepo repo = _MockAIChatRepo();
  late AIChatState state;
  late final AIChatReplyHandler handler;
  String? lastAskQuestion;
  final guardEvents = <Map<String, dynamic>>[];

  AIChatMessage renderStructured(
    AIChatStructuredReply structured, {
    required List<ProductModel> catalog,
    required AIChatRecommendationContext context,
    AIChatLanguage language = AIChatLanguage.english,
    String source = 'ai_worker_v2',
  }) {
    final reply = structured.toAIChatReply(language: language);
    if (reply.isRecommend) {
      final guard =
          FinalRecommendationGuard(
            translate: (language, {required ar, required en}) =>
                language.isArabic ? ar : en,
            logEvent: (eventType, metadata) {
              guardEvents.add({'eventType': eventType, ...metadata});
            },
          ).guard(
            reply: reply,
            catalog: catalog,
            recommendationContext: context,
            language: language,
            responseSource: source,
          );
      if (guard.safeProducts.isNotEmpty) {
        handler.handleRecommendationReply(
          reply,
          guard.safeProducts,
          language: language,
          source: source,
          sessionId: 'pipeline-session',
        );
      } else if (guard.localRecoveryProducts.isNotEmpty) {
        handler.handleRecommendationReply(
          AIChatReply.recommend(
            productIds: guard.localRecoveryProducts
                .map((item) => item.product.id)
                .toList(),
            matchReasons: {
              for (final item in guard.localRecoveryProducts)
                item.product.id: item.matchReason,
            },
            updatedPreferences: reply.updatedPreferences,
            requestId: reply.requestId,
            promptVersion: reply.promptVersion,
            provider: reply.provider,
            modelId: reply.modelId,
          ),
          guard.localRecoveryProducts,
          language: language,
          source: 'ai_worker_safe_recovery',
          sessionId: 'pipeline-session',
        );
      } else {
        handler.replyWithFallback(
          'I could not find an in-stock catalog match that safely respects your current constraints.',
          language: language,
          source: source,
          sessionId: 'pipeline-session',
          requestId: reply.requestId,
          updatedPreferences: reply.updatedPreferences,
          isNoMatch: true,
          issueCode: guard.issueCode ?? 'no_candidate_match',
          reasonCode: guard.reasonCode ?? 'no_candidate_match',
        );
      }
    } else if (reply.isAsk) {
      handler.handleAskReply(
        reply,
        language: language,
        source: source,
        sessionId: 'pipeline-session',
      );
    } else {
      handler.handleAnswerReply(
        reply,
        language: language,
        source: source,
        sessionId: 'pipeline-session',
      );
    }
    return state.messages.last;
  }

  Future<AIChatMessage> renderToolCall(
    AIChatReply toolReply, {
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    RecommendationMemory recommendationMemory = const RecommendationMemory(),
    AIChatLanguage language = AIChatLanguage.english,
  }) async {
    final toolResult = await (const AIChatToolExecutor()).execute(
      reply: toolReply,
      catalog: catalog,
      currentPreferences: currentPreferences,
      language: language,
      recommendationMemory: recommendationMemory,
    );
    if (!toolResult.handled || toolResult.reply == null) {
      handler.replyWithFallback(
        'I could not find an in-stock catalog match that safely respects your current constraints.',
        language: language,
        source: 'tool_execution_failed',
        sessionId: 'pipeline-session',
        requestId: toolReply.requestId,
        updatedPreferences: currentPreferences,
        isNoMatch: true,
        issueCode: toolResult.issueCode ?? 'tool_execution_failed',
        reasonCode: toolResult.reasonCode ?? 'tool_execution_failed',
      );
      return state.messages.last;
    }
    if (toolResult.reply!.isAsk) {
      handler.handleAskReply(
        toolResult.reply!,
        language: language,
        source: toolResult.source,
        sessionId: 'pipeline-session',
      );
      return state.messages.last;
    }
    if (toolResult.reply!.isAnswer) {
      handler.handleAnswerReply(
        toolResult.reply!,
        language: language,
        source: toolResult.source,
        sessionId: 'pipeline-session',
      );
      return state.messages.last;
    }
    final guard =
        FinalRecommendationGuard(
          translate: (language, {required ar, required en}) =>
              language.isArabic ? ar : en,
          logEvent: (eventType, metadata) {
            guardEvents.add({'eventType': eventType, ...metadata});
          },
        ).guard(
          reply: toolResult.reply!,
          catalog: catalog,
          recommendationContext: AIChatRecommendationContext(
            localCandidatesRefs: toolResult.recommendations,
            candidatesList: toolResult.recommendations
                .map((item) => item.product)
                .toList(growable: false),
            localFallbackAnswer: null,
            budgetPolicy: AIChatBudgetPolicy.flexible,
            effectivePreferences: toolResult.preferences,
          ),
          language: language,
          responseSource: toolResult.source,
        );
    if (guard.safeProducts.isEmpty) {
      handler.replyWithFallback(
        'I could not find an in-stock catalog match that safely respects your current constraints.',
        language: language,
        source: toolResult.source,
        sessionId: 'pipeline-session',
        requestId: toolReply.requestId,
        updatedPreferences: toolResult.preferences,
        isNoMatch: true,
        issueCode: guard.issueCode ?? 'no_candidate_match',
        reasonCode: guard.reasonCode ?? 'no_candidate_match',
      );
      return state.messages.last;
    }
    handler.handleRecommendationReply(
      toolResult.reply!,
      guard.safeProducts,
      language: language,
      source: toolResult.source,
      sessionId: 'pipeline-session',
    );
    return state.messages.last;
  }
}

void main() {
  group('Worker v2 headless pipeline', () {
    test(
      'v2 recommendation passes adapter guard handler into state cards',
      () async {
        final product = _product(id: 'safe', price: 900);
        final harness = _PipelineHarness();
        final message = harness.renderStructured(
          _structured({
            'type': 'recommendation',
            'message': 'Here are safe picks.',
            'commands': [
              {
                'action': 'show_recommendation_cards',
                'productIds': ['safe'],
              },
            ],
            'recommendations': [
              {'productId': 'safe', 'reason': 'Fresh and within budget.'},
            ],
          }),
          catalog: [product],
          context: AIChatRecommendationContext(
            localCandidatesRefs: [_candidate(product)],
            candidatesList: [product],
            localFallbackAnswer: null,
            effectivePreferences: const SessionPreferences(maxBudget: 1000),
          ),
        );

        expect(harness.state.status, AIChatStatus.recommend);
        expect(message.isRecommendation, isTrue);
        expect(message.recommendedProducts.single.product.id, 'safe');
        expect(message.promptVersion, 'chat_v2_structured_commands');
        expect(message.provider, 'openrouter');
      },
    );

    test('visible card reasons hide internal suitability codes', () async {
      final product = _product(id: 'safe', price: 900);
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({
          'type': 'recommendation',
          'message': 'Here are safe picks.',
          'commands': [
            {
              'action': 'show_recommendation_cards',
              'productIds': ['safe'],
            },
          ],
          'recommendations': [
            {
              'productId': 'safe',
              'reason':
                  'Matches fruity notes. Suitability: medium_for_light_request.',
            },
          ],
        }),
        catalog: [product],
        context: AIChatRecommendationContext(
          localCandidatesRefs: [_candidate(product)],
          candidatesList: [product],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(),
        ),
      );

      final reason = message.recommendedProducts.single.matchReason;
      expect(reason, contains('Matches fruity notes'));
      expect(reason, isNot(contains('Suitability:')));
      expect(reason, isNot(contains('medium_for_light_request')));
    });

    test(
      'over-budget worker IDs are filtered before state rendering',
      () async {
        final expensive = _product(id: 'expensive', price: 1500);
        final safe = _product(id: 'safe', price: 800);
        final harness = _PipelineHarness();
        final message = harness.renderStructured(
          _structured({
            'type': 'recommendation',
            'commands': [
              {
                'action': 'show_recommendation_cards',
                'productIds': ['expensive', 'safe'],
              },
            ],
          }),
          catalog: [expensive, safe],
          context: AIChatRecommendationContext(
            localCandidatesRefs: [_candidate(safe)],
            candidatesList: [safe],
            localFallbackAnswer: null,
            budgetPolicy: AIChatBudgetPolicy.strict,
            effectivePreferences: const SessionPreferences(maxBudget: 900),
          ),
        );

        expect(message.recommendedProducts.map((item) => item.product.id), [
          'safe',
        ]);
        expect(
          harness.guardEvents.any(
            (event) => event['issueCode'] == 'budget_policy_block',
          ),
          isTrue,
        );
      },
    );

    test(
      'excluded notes are filtered before reply handler renders cards',
      () async {
        final vanilla = _product(
          id: 'vanilla',
          price: 800,
          notes: const ['vanilla', 'musk'],
        );
        final safe = _product(id: 'safe', price: 750);
        final harness = _PipelineHarness();
        final message = harness.renderStructured(
          _structured({
            'type': 'recommendation',
            'commands': [
              {
                'action': 'show_recommendation_cards',
                'productIds': ['vanilla', 'safe'],
              },
            ],
          }),
          catalog: [vanilla, safe],
          context: AIChatRecommendationContext(
            localCandidatesRefs: [_candidate(safe)],
            candidatesList: [safe],
            localFallbackAnswer: null,
            effectivePreferences: const SessionPreferences(
              maxBudget: 1000,
              excludedNotes: ['vanilla'],
            ),
          ),
        );

        expect(message.recommendedProducts.map((item) => item.product.id), [
          'safe',
        ]);
        expect(
          harness.guardEvents.any(
            (event) => event['issueCode'] == 'excluded_note_violation',
          ),
          isTrue,
        );
      },
    );

    test('medical allergy text is locked by answer grounding', () async {
      final harness = _PipelineHarness(
        initialState: AIChatState(
          messages: [AIChatMessage.loading()],
          preferences: const SessionPreferences(
            medicalExcludedNotes: ['vanilla'],
          ),
        ),
      );
      final message = harness.renderStructured(
        _structured({
          'type': 'message',
          'message': 'Sure, I can recommend vanilla safely.',
        }),
        catalog: const [],
        context: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
      );

      expect(harness.state.status, AIChatStatus.noMatch);
      expect(message.content, isNot(contains('recommend vanilla')));
      expect(message.workerFailureReason, 'answer_mentions_excluded_note');
    });

    test('no_match becomes safe no-match state', () async {
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({'type': 'no_match', 'message': 'No safe match.'}),
        catalog: const [],
        context: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
      );

      expect(harness.state.status, AIChatStatus.answer);
      expect(message.type, MessageType.text);
      expect(message.content, 'No safe match.');
    });

    test('ask reply updates ask state and keeps worker metadata', () async {
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({
          'type': 'ask',
          'message': 'Do you prefer men, women, or unisex?',
        }),
        catalog: const [],
        context: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
      );

      expect(harness.state.status, AIChatStatus.ask);
      expect(message.content, contains('men'));
      expect(message.promptVersion, 'chat_v2_structured_commands');
    });

    test('refusal reply remains text-only without cards', () async {
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({
          'type': 'refusal',
          'message':
              'I cannot ignore system rules or invent products outside the catalog.',
        }),
        catalog: const [],
        context: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
      );

      expect(harness.state.status, AIChatStatus.answer);
      expect(message.recommendedProducts, isEmpty);
      expect(message.content, contains('cannot ignore'));
    });

    test('mojibake-blocked response never exposes raw mojibake text', () async {
      final harness = _PipelineHarness();
      final reply = AIChatReply.answer(
        answer:
            'РЁР„Р©вЂ¦РЁВ§Р©вЂ¦РЁРЉ Р©РѓР©вЂЎР©вЂ¦РЁР„ РЁВ·Р©вЂћРЁРЃР©С“. Р©вЂЎРЁВ±РЁВ§РЁВ¬РЁв„– РЁВ§Р©вЂћРЁР„Р©РѓРЁВ¶Р©Р‰Р©вЂћРЁВ§РЁР„ РЁВ§Р©вЂћРЁВ­РЁВ§Р©вЂћР©Р‰РЁВ©.',
        updatedPreferences: const SessionPreferences(),
        promptVersion: 'chat_v2_structured_commands',
        provider: 'openrouter',
        modelId: 'qwen/qwen3-32b',
      );

      harness.handler.handleAnswerReply(
        reply,
        language: AIChatLanguage.arabic,
        source: 'ai_worker_mojibake_blocked',
        sessionId: 'pipeline-session',
      );

      final message = harness.state.messages.last;
      expect(message.content, isNot(contains('Р В©')));
      expect(message.content, isNot(contains('Р“С’')));
      expect(message.responseSource, 'ai_worker_mojibake_blocked');
      expect(message.provider, 'openrouter');
    });

    test('malformed command is ignored and does not render cards', () async {
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({
          'type': 'recommendation',
          'message': 'Malformed command ignored.',
          'commands': [
            {
              'action': 'clear_cards',
              'productIds': ['safe'],
            },
          ],
        }),
        catalog: [_product(id: 'safe', price: 900)],
        context: const AIChatRecommendationContext(
          localCandidatesRefs: [],
          candidatesList: [],
          localFallbackAnswer: null,
        ),
      );

      expect(harness.state.status, AIChatStatus.answer);
      expect(message.recommendedProducts, isEmpty);
      expect(message.content, 'Malformed command ignored.');
    });

    test('safe recovery keeps worker metadata and recovery source', () async {
      final blocked = _product(id: 'blocked', price: 2000);
      final safe = _product(id: 'safe', price: 800);
      final harness = _PipelineHarness();
      final message = harness.renderStructured(
        _structured({
          'type': 'recommendation',
          'commands': [
            {
              'action': 'show_recommendation_cards',
              'productIds': ['blocked'],
            },
          ],
        }),
        catalog: [blocked, safe],
        context: AIChatRecommendationContext(
          localCandidatesRefs: [_candidate(safe)],
          candidatesList: [safe],
          localFallbackAnswer: null,
          effectivePreferences: const SessionPreferences(maxBudget: 900),
        ),
      );

      expect(harness.state.status, AIChatStatus.recommend);
      expect(message.responseSource, 'ai_worker_safe_recovery');
      expect(message.promptVersion, 'chat_v2_structured_commands');
      expect(message.provider, 'openrouter');
      expect(message.recommendedProducts.single.product.id, 'safe');
    });

    test('tool_call executes app-side search guard and render path', () async {
      final safe = _product(
        id: 'safe-tool',
        name: 'Safe Tool Fresh',
        price: 900,
        gender: 'men',
        season: 'summer',
        occasion: 'daily',
        intensity: 'light',
        tags: const ['fresh', 'clean'],
      );
      final blocked = _product(
        id: 'blocked-tool',
        name: 'Blocked Tool',
        price: 700,
        gender: 'men',
        season: 'summer',
        stock: 0,
        tags: const ['fresh'],
      );
      final harness = _PipelineHarness();
      final message = await harness.renderToolCall(
        AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.searchProducts,
            arguments: {
              'gender': 'men',
              'season': 'summer',
              'tags': ['fresh'],
              'limit': 3,
            },
          ),
          updatedPreferences: const SessionPreferences(),
          requestId: 'tool-pipeline',
        ),
        catalog: [safe, blocked],
        currentPreferences: const SessionPreferences(),
      );

      expect(message.isRecommendation, isTrue);
      expect(message.recommendedProducts.map((item) => item.product.id), [
        'safe-tool',
      ]);
      expect(
        message.recommendedProducts.every(
          (item) => item.product.stock > 0 && item.product.isActive,
        ),
        isTrue,
      );
    });

    test('external profile similar tool renders catalog-only cards', () async {
      final close = _product(
        id: 'close-sauvage-alt',
        name: 'Fresh Pepper Woods',
        price: 2600,
        gender: 'men',
        notes: const ['bergamot', 'pepper', 'ambroxan', 'woody'],
        topNotes: const ['bergamot'],
        middleNotes: const ['pepper'],
        baseNotes: const ['ambroxan', 'woody'],
        tags: const ['fresh', 'spicy', 'masculine'],
      );
      final far = _product(
        id: 'external-profile-id-should-not-render',
        name: 'Dior Sauvage External Placeholder',
        price: 0,
        stock: 0,
        gender: 'men',
        notes: const ['bergamot'],
      );
      final harness = _PipelineHarness();
      final message = await harness.renderToolCall(
        AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.recommendSimilarToExternalProfile,
            arguments: {'externalProfileId': 'dior_sauvage'},
          ),
          updatedPreferences: const SessionPreferences(),
          requestId: 'external-similar',
        ),
        catalog: [close, far],
        currentPreferences: const SessionPreferences(gender: 'men'),
        recommendationMemory: const RecommendationMemory(
          lastExternalProfile: ExternalProfileRef(
            id: 'dior_sauvage',
            name: 'Dior Sauvage',
            brand: 'Dior',
            fragranceFamily: 'fresh spicy',
            notes: ['bergamot', 'pepper', 'ambroxan', 'woody'],
            tags: ['fresh', 'spicy', 'masculine'],
            confidence: 0.91,
          ),
        ),
      );

      expect(message.isRecommendation, isTrue);
      expect(message.responseSource, 'tool_recommendSimilarToExternalProfile');
      expect(message.recommendedProducts.map((item) => item.product.id), [
        'close-sauvage-alt',
      ]);
      expect(
        message.recommendedProducts.map((item) => item.product.id),
        isNot(contains('dior_sauvage')),
      );
      expect(
        message.recommendedProducts.every(
          (item) => item.product.stock > 0 && item.product.isActive,
        ),
        isTrue,
      );
    });

    test('external cheaper tool respects verified price reference', () async {
      final below = _product(
        id: 'below-ref',
        name: 'Below Reference',
        price: 3200,
        gender: 'men',
        notes: const ['bergamot', 'pepper', 'woody'],
        tags: const ['fresh', 'spicy'],
      );
      final above = _product(
        id: 'above-ref',
        name: 'Above Reference',
        price: 5500,
        gender: 'men',
        notes: const ['bergamot', 'pepper', 'woody'],
        tags: const ['fresh', 'spicy'],
      );
      final harness = _PipelineHarness();
      final message = await harness.renderToolCall(
        AIChatReply.toolCall(
          toolCall: const AIChatToolCall(
            name: AIChatToolName.similarCheaperToExternalProfile,
            arguments: {'externalProfileId': 'dior_sauvage'},
          ),
          updatedPreferences: const SessionPreferences(),
          requestId: 'external-cheaper',
        ),
        catalog: [below, above],
        currentPreferences: const SessionPreferences(gender: 'men'),
        recommendationMemory: const RecommendationMemory(
          lastExternalProfile: ExternalProfileRef(
            id: 'dior_sauvage',
            name: 'Dior Sauvage',
            notes: ['bergamot', 'pepper', 'woody'],
            tags: ['fresh', 'spicy'],
            confidence: 0.91,
            priceReference: 5000,
          ),
        ),
      );

      expect(message.isRecommendation, isTrue);
      expect(message.responseSource, 'tool_similarCheaperToExternalProfile');
      expect(message.recommendedProducts.map((item) => item.product.id), [
        'below-ref',
      ]);
      expect(
        message.recommendedProducts.every(
          (item) => item.product.effectivePrice < 5000,
        ),
        isTrue,
      );
    });

    test(
      'external cheaper tool without price keeps disclosure and no claim',
      () async {
        final similar = _product(
          id: 'similar-no-price',
          name: 'Similar Without Price',
          price: 8000,
          gender: 'men',
          notes: const ['bergamot', 'pepper', 'woody'],
          tags: const ['fresh', 'spicy'],
        );
        final harness = _PipelineHarness();
        final message = await harness.renderToolCall(
          AIChatReply.toolCall(
            toolCall: const AIChatToolCall(
              name: AIChatToolName.similarCheaperToExternalProfile,
              arguments: {'externalProfileId': 'dior_sauvage'},
            ),
            updatedPreferences: const SessionPreferences(),
            requestId: 'external-cheaper-no-price',
          ),
          catalog: [similar],
          currentPreferences: const SessionPreferences(gender: 'men'),
          recommendationMemory: const RecommendationMemory(
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              notes: ['bergamot', 'pepper', 'woody'],
              tags: ['fresh', 'spicy'],
              confidence: 0.91,
            ),
          ),
        );

        expect(message.isRecommendation, isTrue);
        final reason = message.recommendedProducts.single.matchReason;
        expect(reason, contains('cannot verify'));
        expect(reason, isNot(contains('below the verified reference price')));
      },
    );

    test(
      'external profile tool rejects ungrounded profile id with no cards',
      () async {
        final harness = _PipelineHarness();
        final message = await harness.renderToolCall(
          AIChatReply.toolCall(
            toolCall: const AIChatToolCall(
              name: AIChatToolName.recommendSimilarToExternalProfile,
              arguments: {'externalProfileId': 'invented_profile'},
            ),
            updatedPreferences: const SessionPreferences(),
            requestId: 'external-ungrounded',
          ),
          catalog: [_product(id: 'safe', price: 900)],
          currentPreferences: const SessionPreferences(),
          recommendationMemory: const RecommendationMemory(
            lastExternalProfile: ExternalProfileRef(
              id: 'dior_sauvage',
              name: 'Dior Sauvage',
              notes: ['fresh'],
            ),
          ),
        );

        expect(message.isRecommendation, isFalse);
        expect(message.recommendedProducts, isEmpty);
        expect(harness.state.status, AIChatStatus.noMatch);
      },
    );
  });
}
