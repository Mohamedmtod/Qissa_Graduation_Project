import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatConversationPlan {
  const AIChatConversationPlan({
    required this.intent,
    required this.cardPolicy,
    required this.shouldPreferWorker,
    required this.safeFallbackPlan,
  });

  final AIChatConversationIntent intent;
  final AIChatCardPolicy cardPolicy;
  final bool shouldPreferWorker;
  final String safeFallbackPlan;
}

class AIChatConversationOrchestrator {
  const AIChatConversationOrchestrator();

  AIChatConversationPlan plan({
    required String message,
    required AIChatLanguage language,
    required SessionPreferences preferences,
    required RecommendationMemory memory,
    required bool hasRecommendationContext,
  }) {
    final normalized = LocalIntentParser.normalizeInput(message);
    final intent = _classifyIntent(
      normalized,
      hasRecommendationContext: hasRecommendationContext,
    );
    return AIChatConversationPlan(
      intent: intent,
      cardPolicy: _cardPolicy(intent),
      shouldPreferWorker: _shouldPreferWorker(intent),
      safeFallbackPlan: _fallbackPlan(intent, preferences, memory, language),
    );
  }

  AIChatConversationIntent _classifyIntent(
    String normalized, {
    required bool hasRecommendationContext,
  }) {
    if (_looksSocial(normalized)) {
      return AIChatConversationIntent.social;
    }
    if (_looksBusinessInfo(normalized)) {
      return AIChatConversationIntent.businessInfo;
    }
    if (_looksAvailability(normalized)) {
      return AIChatConversationIntent.availability;
    }
    if (_looksVisibleQuestion(normalized, hasRecommendationContext)) {
      return AIChatConversationIntent.visibleProductsQuestion;
    }
    if (_looksAdvisory(normalized)) return AIChatConversationIntent.advisory;
    if (normalized.contains('similar') ||
        normalized.contains('cheaper') ||
        normalized.contains('شبه') ||
        normalized.contains('ارخص')) {
      return AIChatConversationIntent.catalogRecommendation;
    }
    return AIChatConversationIntent.catalogRecommendation;
  }

  AIChatCardPolicy _cardPolicy(AIChatConversationIntent intent) {
    return switch (intent) {
      AIChatConversationIntent.social ||
      AIChatConversationIntent.advisory ||
      AIChatConversationIntent.visibleProductsQuestion ||
      AIChatConversationIntent.businessInfo => AIChatCardPolicy.answerOnly,
      AIChatConversationIntent.clarification ||
      AIChatConversationIntent.noMatch => AIChatCardPolicy.noCards,
      AIChatConversationIntent.availability => AIChatCardPolicy.purchaseCtaCard,
      AIChatConversationIntent.catalogRecommendation ||
      AIChatConversationIntent.externalReference =>
        AIChatCardPolicy.recommendationGrid,
      AIChatConversationIntent.productContextAnswer =>
        AIChatCardPolicy.answerOnly,
      AIChatConversationIntent.unknown => AIChatCardPolicy.noCards,
    };
  }

  bool _shouldPreferWorker(AIChatConversationIntent intent) {
    return switch (intent) {
      AIChatConversationIntent.social ||
      AIChatConversationIntent.advisory ||
      AIChatConversationIntent.catalogRecommendation ||
      AIChatConversationIntent.externalReference => true,
      _ => false,
    };
  }

  String _fallbackPlan(
    AIChatConversationIntent intent,
    SessionPreferences preferences,
    RecommendationMemory memory,
    AIChatLanguage language,
  ) {
    if (intent == AIChatConversationIntent.social) {
      return 'social_answer';
    }
    if (intent == AIChatConversationIntent.visibleProductsQuestion &&
        memory.lastRecommendedProducts.isNotEmpty) {
      return 'answer_visible_products';
    }
    if (preferences.canRecommendInitial ||
        preferences.canRefineExistingRecommendation(
          hasRecommendationContext: memory.lastRecommendedProducts.isNotEmpty,
        )) {
      return 'recommend_from_safe_candidates';
    }
    return language.isArabic ? 'ask_one_arabic_slot' : 'ask_one_english_slot';
  }

  bool _looksSocial(String normalized) {
    final compact = normalized.replaceAll(RegExp(r'[^a-z\u0600-\u06ff ]'), ' ');
    return RegExp(
      r'(^|\s)(hello|hi|hey|how are you|thanks|thank you|صباح الخير|مساء الخير|ازيك|عامل ايه|اهلا|مرحبا)(\s|$)',
    ).hasMatch(compact);
  }

  bool _looksAvailability(String normalized) {
    return normalized.contains('do you have') ||
        normalized.contains('available') ||
        normalized.contains('عندك') ||
        normalized.contains('متوفر');
  }

  bool _looksVisibleQuestion(String normalized, bool hasRecommendationContext) {
    if (!hasRecommendationContext) return false;
    return normalized.contains('which') ||
        normalized.contains('first') ||
        normalized.contains('second') ||
        normalized.contains('cheapest') ||
        normalized.contains('ارخص') ||
        normalized.contains('الاول') ||
        normalized.contains('التاني');
  }

  bool _looksBusinessInfo(String normalized) {
    return normalized.contains('payment') ||
        normalized.contains('delivery') ||
        normalized.contains('contact') ||
        normalized.contains('الدفع') ||
        normalized.contains('التوصيل') ||
        normalized.contains('التواصل');
  }

  bool _looksAdvisory(String normalized) {
    return normalized.contains('what is') ||
        normalized.contains('difference between') ||
        normalized.contains('يعني ايه') ||
        normalized.contains('الفرق بين');
  }
}
