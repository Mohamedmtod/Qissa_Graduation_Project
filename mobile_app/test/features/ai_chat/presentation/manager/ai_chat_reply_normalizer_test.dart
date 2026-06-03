import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/preference_patch.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

ProductModel _product(String id) {
  final now = Timestamp.now();
  return ProductModel(
    id: id,
    name: 'Office Fit',
    nameLower: 'office fit',
    searchPrefixes: const ['off', 'office'],
    brand: 'Brand',
    price: 950,
    stock: 5,
    gender: 'men',
    season: 'summer',
    fragranceFamily: 'fresh',
    notes: const ['citrus'],
    imageUrls: const ['https://example.com/p.png'],
    description: 'test',
    categoryName: 'Perfume',
    createdAt: now,
    updatedAt: now,
    occasion: 'daily',
    time: 'day',
    intensity: 'medium',
    topNotes: const ['citrus'],
    middleNotes: const ['jasmine'],
    baseNotes: const ['musk'],
    tags: const ['clean'],
  );
}

bool _missingFoundationalSlots(
  SessionPreferences preferences, {
  required bool hasRecommendationContext,
}) {
  if (hasRecommendationContext) return false;
  return preferences.gender == null || preferences.season == null;
}

void main() {
  test('office lifestyle ask is normalized into recommendation', () {
    final reply = AIChatReply.ask(
      question: 'هل تبحث عن عطر رجالي أم نسائي؟',
      updatedPreferences: const SessionPreferences(
        occasion: 'office',
        time: 'all_day',
        intensity: 'light',
        tags: ['clean', 'elegant'],
      ),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.76,
        matchLabel: 'Great Match',
        matchReason: 'test',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'عطر للـ Office استخدمه كل يوم.',
      localCandidates: localCandidates,
      language: AIChatLanguage.arabic,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isTrue);
    expect(normalized.productIds, equals(['p1']));
  });

  test('weak local candidates do not override worker ask', () {
    final reply = AIChatReply.ask(
      question: 'Do you prefer men or women fragrances?',
      updatedPreferences: const SessionPreferences(
        gender: 'men',
        season: 'summer',
        occasion: 'office',
      ),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.42,
        matchLabel: 'Weak Match',
        matchReason: 'weak candidate',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'I need something for the office',
      localCandidates: localCandidates,
      language: AIChatLanguage.english,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isFalse);
    expect(normalized.isAsk, isTrue);
    expect(normalized.question, isNot(reply.question));
  });

  test('filled-slot ask can use safe partial filtered candidates', () {
    final reply = AIChatReply.ask(
      question: 'Do you prefer men or women fragrances?',
      updatedPreferences: const SessionPreferences(
        gender: 'men',
        maxBudget: 1500,
        occasion: 'office',
        preferredNotes: ['woody'],
        tags: ['smoky', 'elegant', 'classic'],
      ),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.49,
        matchLabel: 'Partial Match',
        matchReason: 'filtered candidate',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'Recommend the best match for me.',
      localCandidates: localCandidates,
      language: AIChatLanguage.english,
      hasRecommendationContext: true,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isTrue);
    expect(normalized.productIds, equals(['p1']));
  });

  test(
    'filled-slot ask without safe candidates retargets away from that slot',
    () {
      final reply = AIChatReply.ask(
        question: 'Do you prefer men or women fragrances?',
        updatedPreferences: const SessionPreferences(gender: 'men'),
      );

      final normalized = normalizeAskReply(
        reply,
        message: 'I am a man.',
        localCandidates: const [],
        language: AIChatLanguage.english,
        hasRecommendationContext: false,
        lastAskQuestion: null,
        hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
      );

      expect(normalized.isAsk, isTrue);
      expect(normalized.question, isNot(reply.question));
      expect(normalized.question, contains('summer'));
    },
  );

  test('redundant filled-slot ask overrides only with strong candidates', () {
    final reply = AIChatReply.ask(
      question: 'Do you prefer men or women fragrances?',
      updatedPreferences: const SessionPreferences(
        gender: 'men',
        season: 'summer',
        occasion: 'office',
      ),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.72,
        matchLabel: 'Great Match',
        matchReason: 'strong candidate',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'I need something for the office',
      localCandidates: localCandidates,
      language: AIChatLanguage.english,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isTrue);
    expect(normalized.productIds, equals(['p1']));
  });

  test('practical-ready request can override generic foundational ask', () {
    final reply = AIChatReply.ask(
      question: 'Do you prefer men or women fragrances?',
      updatedPreferences: const SessionPreferences(
        maxBudget: 1200,
        tags: ['fresh'],
      ),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.72,
        matchLabel: 'Great Match',
        matchReason: 'fresh and within budget',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'Recommend a fresh perfume under 1200.',
      localCandidates: localCandidates,
      language: AIChatLanguage.english,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isTrue);
    expect(normalized.productIds, equals(['p1']));
  });

  test('budget-only request still does not override foundational ask', () {
    final reply = AIChatReply.ask(
      question: 'Do you prefer men or women fragrances?',
      updatedPreferences: const SessionPreferences(maxBudget: 1200),
    );
    final localCandidates = [
      RecommendedProduct(
        product: _product('p1'),
        matchScore: 0.72,
        matchLabel: 'Great Match',
        matchReason: 'within budget',
      ),
    ];

    final normalized = normalizeAskReply(
      reply,
      message: 'Recommend perfume under 1200.',
      localCandidates: localCandidates,
      language: AIChatLanguage.english,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isRecommend, isFalse);
    expect(normalized.isAsk, isTrue);
  });

  test('generic ask is retargeted to a concrete missing slot', () {
    final reply = AIChatReply.ask(
      question:
          'Could you share one more preference so I can refine the recommendation?',
      updatedPreferences: const SessionPreferences(
        maxBudget: 1800,
        occasion: 'formal',
      ),
    );

    final normalized = normalizeAskReply(
      reply,
      message: 'Suggest a classy perfume gift for my manager under 1800.',
      localCandidates: const <RecommendedProduct>[],
      language: AIChatLanguage.english,
      hasRecommendationContext: false,
      lastAskQuestion: null,
      hasMissingFoundationalDiscoverySlots: _missingFoundationalSlots,
    );

    expect(normalized.isAsk, isTrue);
    expect(normalized.question, contains('men'));
    expect(normalized.question, contains('women'));
  });

  test(
    'mergeReplyPreferences applies explicit preference patch after merge',
    () {
      final reply = AIChatReply.ask(
        question: 'Updated.',
        updatedPreferences: const SessionPreferences(gender: 'men'),
        preferencePatch: PreferencePatch()
          ..clearScalar(PreferenceScalar.maxBudget)
          ..removeFromList(PreferenceListField.preferredNotes, ['oud']),
      );

      final merged = mergeReplyPreferences(
        reply,
        basePreferences: const SessionPreferences(
          gender: 'men',
          maxBudget: 1500,
          preferredNotes: ['oud', 'citrus'],
        ),
      );

      expect(merged.updatedPreferences.maxBudget, isNull);
      expect(merged.updatedPreferences.preferredNotes, ['citrus']);
    },
  );
}
