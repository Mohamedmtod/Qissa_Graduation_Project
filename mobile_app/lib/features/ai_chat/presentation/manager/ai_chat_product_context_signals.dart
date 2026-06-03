class AIChatProductContextSignals {
  const AIChatProductContextSignals();

  bool looksLikeContextSuitabilityQuestion(String normalized) {
    if (normalized.isEmpty) return false;
    final asksFit =
        RegExp(
          r'\b(suitable|fit|fits|good for|work for|works for|okay for|ok for|appropriate for|can i wear|wear it)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u064a\u0646\u0641\u0639') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628');
    if (!asksFit) return false;
    return extractContextLabel(normalized) != null ||
        normalized.contains('occasion') ||
        normalized.contains('\u0645\u0646\u0627\u0633\u0628\u0629');
  }

  String? classifyRecommendationRefinementConflict(String normalized) {
    if (normalized.isEmpty) return null;
    if (extractContextLabel(normalized) == null) return null;
    if (!looksLikeContextSuitabilityQuestion(normalized)) return null;
    if (looksLikeExplicitProductContextQuestion(normalized)) return null;

    final hasClearRefinementVerb =
        RegExp(
          r'\b(want|need|make|change|switch|turn|keep|show|find|recommend)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u062e\u0644\u064a') ||
        normalized.contains('\u0639\u0627\u064a\u0632') ||
        normalized.contains('\u0639\u0627\u0648\u0632');
    final hasRecommendationTarget =
        RegExp(
          r'\b(it|them|this|that|these|options?|recommendations?|perfumes?)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u062f\u0647') ||
        normalized.contains('\u062f\u064a') ||
        normalized.contains('\u062f\u0648\u0644');
    final hasMessyRefinementSignal =
        RegExp(r'\b(w+antit|wantit|wanit|wnt|wwant)\b').hasMatch(normalized) ||
        normalized.contains('too suitable') ||
        normalized.contains('to suitable');

    if (hasMessyRefinementSignal) return 'llm';
    if (hasClearRefinementVerb && hasRecommendationTarget) {
      return 'refinement';
    }
    return null;
  }

  bool looksLikeExplicitProductContextQuestion(String normalized) {
    final startsWithQuestionVerb =
        RegExp(
          r'^\s*(is|are|does|do|can|could|will|would|should)\b',
        ).hasMatch(normalized) ||
        normalized.startsWith('\u0647\u0644 ') ||
        normalized.startsWith('\u064a\u0646\u0641\u0639');
    if (!startsWithQuestionVerb) return false;
    return RegExp(
          r'\b(it|this|that|one|product|perfume|recommendation|option|they|them)\b',
        ).hasMatch(normalized) ||
        normalized.contains('\u062f\u0647') ||
        normalized.contains('\u062f\u064a') ||
        normalized.contains('\u0627\u0644\u0639\u0637\u0631');
  }

  String? extractContextLabel(String normalized) {
    if (normalized.contains('office') ||
        normalized.contains('work') ||
        normalized.contains('job') ||
        normalized.contains('\u0634\u063a\u0644') ||
        normalized.contains('\u0627\u0644\u0634\u063a\u0644') ||
        normalized.contains('\u0645\u0643\u062a\u0628')) {
      return 'office';
    }
    if (normalized.contains('university') ||
        normalized.contains('campus') ||
        normalized.contains('\u062c\u0627\u0645\u0639\u0629') ||
        normalized.contains('\u0644\u0644\u062c\u0627\u0645\u0639\u0629')) {
      return 'university';
    }
    if (normalized.contains('gym') ||
        normalized.contains('workout') ||
        normalized.contains('\u062c\u064a\u0645')) {
      return 'gym';
    }
    if (normalized.contains('date') ||
        normalized.contains('romantic') ||
        normalized.contains('\u0645\u0648\u0639\u062f') ||
        normalized.contains('\u062e\u0637\u064a\u0628')) {
      return 'date';
    }
    if (normalized.contains('daily') ||
        normalized.contains('everyday') ||
        normalized.contains('\u064a\u0648\u0645\u064a')) {
      return 'daily';
    }
    return null;
  }
}
