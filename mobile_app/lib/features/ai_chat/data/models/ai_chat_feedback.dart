enum AIChatFeedbackReason {
  wrongRecommendation('wrong_recommendation'),
  wrongGender('wrong_gender'),
  wrongOccasion('wrong_occasion'),
  tooExpensive('too_expensive'),
  notSimilar('not_similar'),
  repeatedProducts('repeated_products'),
  badArabic('bad_arabic'),
  slowResponse('slow_response'),
  confusingAnswer('confusing_answer'),
  externalLookupWrong('external_lookup_wrong'),
  availabilityWrong('availability_wrong'),
  other('other');

  const AIChatFeedbackReason(this.value);

  final String value;

  static AIChatFeedbackReason? fromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    for (final reason in AIChatFeedbackReason.values) {
      if (reason.value == normalized) return reason;
    }
    return null;
  }
}

class AIChatFeedback {
  const AIChatFeedback({
    required this.sessionId,
    required this.messageId,
    required this.isHelpful,
    this.note,
    this.reason,
    this.turnId,
    this.requestId,
    this.sessionIdHash,
  });

  final String sessionId;
  final String messageId;
  final bool isHelpful;
  final String? note;
  final AIChatFeedbackReason? reason;
  final String? turnId;
  final String? requestId;
  final String? sessionIdHash;

  String get feedbackValue => isHelpful ? 'up' : 'down';
}
