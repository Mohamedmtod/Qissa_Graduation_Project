import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_response_facts.dart';

class AIChatResponseQualityDecision {
  const AIChatResponseQualityDecision.allowed()
    : isAllowed = true,
      reasonCode = null;

  const AIChatResponseQualityDecision.blocked(this.reasonCode)
    : isAllowed = false;

  final bool isAllowed;
  final String? reasonCode;
}

class AIChatResponseQualityGuard {
  const AIChatResponseQualityGuard();

  AIChatResponseQualityDecision validateText({
    required AIChatConversationIntent intent,
    required AIChatCardPolicy cardPolicy,
    required String text,
  }) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const AIChatResponseQualityDecision.blocked('empty_text');
    }
    if (_mentionsInternalPrompt(normalized)) {
      return const AIChatResponseQualityDecision.blocked('internal_leak');
    }
    if (intent == AIChatConversationIntent.social) {
      if (_looksAvailabilityPrompt(normalized)) {
        return const AIChatResponseQualityDecision.blocked(
          'social_availability_wording',
        );
      }
      if (_looksGenericPreferencePrompt(normalized)) {
        return const AIChatResponseQualityDecision.blocked(
          'social_generic_preference_prompt',
        );
      }
    }
    if (cardPolicy == AIChatCardPolicy.recommendationGrid &&
        _isGenericRecommendationIntro(normalized)) {
      return const AIChatResponseQualityDecision.blocked(
        'generic_recommendation_intro',
      );
    }
    return const AIChatResponseQualityDecision.allowed();
  }

  AIChatResponseQualityDecision validateFacts(AIChatResponseFacts facts) {
    if (facts.cardPolicy == AIChatCardPolicy.answerOnly &&
        facts.products.isNotEmpty) {
      return const AIChatResponseQualityDecision.blocked(
        'answer_only_has_products',
      );
    }
    if (facts.cardPolicy == AIChatCardPolicy.noCards &&
        facts.products.isNotEmpty) {
      return const AIChatResponseQualityDecision.blocked(
        'no_cards_has_products',
      );
    }
    if (facts.cardPolicy == AIChatCardPolicy.recommendationGrid &&
        facts.products.isEmpty &&
        facts.intent != AIChatConversationIntent.noMatch) {
      return const AIChatResponseQualityDecision.blocked(
        'recommendation_missing_products',
      );
    }
    final text = facts.answer ?? facts.question;
    if (text != null && text.trim().isNotEmpty) {
      return validateText(
        intent: facts.intent,
        cardPolicy: facts.cardPolicy,
        text: text,
      );
    }
    return const AIChatResponseQualityDecision.allowed();
  }

  bool _looksAvailabilityPrompt(String normalized) {
    return normalized.contains('check availability') ||
        normalized.contains('specific perfume') ||
        normalized.contains('do you want me to check') ||
        normalized.contains('اتأكد من توفر') ||
        normalized.contains('اسم العطر');
  }

  bool _looksGenericPreferencePrompt(String normalized) {
    return normalized.contains('tell me your preferences like gender') ||
        normalized.contains('gender, notes, or budget') ||
        normalized.contains('النوع أو النوتات أو الميزانية');
  }

  bool _isGenericRecommendationIntro(String normalized) {
    return normalized ==
            'based on your preferences, these are the best matches for you right now.' ||
        normalized.contains(
          'closest available catalog options for your request',
        );
  }

  bool _mentionsInternalPrompt(String normalized) {
    return normalized.contains('system prompt') ||
        normalized.contains('developer message') ||
        normalized.contains('json schema');
  }
}
