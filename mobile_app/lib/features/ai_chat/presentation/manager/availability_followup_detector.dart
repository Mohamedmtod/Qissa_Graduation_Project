import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';

const Set<String> _availabilityFollowUpKeywords = {
  '\u0634\u0628\u0647',
  '\u0634\u0628\u0647\u0647',
  '\u0632\u064a\u0647',
  '\u0642\u0631\u064a\u0628 \u0645\u0646\u0647',
  '\u0628\u062f\u064a\u0644',
  '\u0645\u0634\u0627\u0628\u0647',
  'something similar',
  'something like',
  'something like it',
  'similar',
  'alternative',
  'closest thing',
  'closest thing you have',
  'closest alternative',
  'closest available',
};

const Set<String> _similarityTerms = {
  '\u0634\u0628\u0647',
  '\u0634\u0628\u0647\u0647',
  '\u0632\u064a\u0647',
  '\u0642\u0631\u064a\u0628 \u0645\u0646\u0647',
  '\u0632\u064a',
  '\u0628\u062f\u064a\u0644',
  '\u0645\u0634\u0627\u0628\u0647',
  'similar',
  'like it',
  'something like',
  'like this',
  'something like it',
  'alternative',
  'closest',
  'closest thing',
  'closest alternative',
};

const Set<String> _cheaperTerms = {
  'cheaper',
  'lower price',
  'less expensive',
  'more affordable',
  'budget',
  '\u0627\u0631\u062e\u0635',
  '\u0623\u0631\u062e\u0635',
  '\u0628\u0633 \u0627\u0631\u062e\u0635',
  '\u0628\u0633 \u0623\u0631\u062e\u0635',
  '\u0627\u0642\u0644',
  '\u0633\u0639\u0631 \u0627\u0642\u0644',
};

const Set<String> _contextReferenceTerms = {
  'it',
  'this',
  'that',
  '\u062f\u0647',
  '\u062f\u064a',
  '\u062f\u0627',
  '\u062d\u0627\u062c\u0629',
  '\u062d\u0627\u062c\u0647',
};

const Set<String> _nonConcreteAvailabilityTokens = {
  'is',
  'there',
  'any',
  'show',
  'me',
  'one',
  'something',
  'but',
  'do',
  'you',
  'have',
  'available',
  'stock',
  'in',
  'the',
  'a',
  'an',
  'perfume',
  'fragrance',
  'like',
  'it',
  'this',
  'that',
  'similar',
  'alternative',
  'closest',
  'lower',
  'price',
  'cheaper',
  'less',
  'more',
  'affordable',
  'budget',
  'to',
  'for',
  'please',
  'can',
  'could',
  'would',
  'u',
  '\u0639\u0637\u0631',
  '\u0628\u0631\u0641\u0627\u0646',
  '\u0632\u064a\u0647',
  '\u0634\u0628\u0647\u0647',
  '\u0645\u0634\u0627\u0628\u0647',
  '\u0628\u062f\u064a\u0644',
  '\u0628\u062f\u064a\u0644\u0647',
  '\u062d\u0627\u062c\u0629',
  '\u062d\u0627\u062c\u0647',
  '\u0627\u064a',
  '\u0627\u064a\u0647',
  '\u0637\u0628',
  '\u0648\u0627\u062d\u062f',
  '\u0648\u0627\u062d\u062f\u0629',
  '\u0627\u0631\u062e\u0635',
  '\u0623\u0631\u062e\u0635',
  '\u0627\u0642\u0644',
  '\u0633\u0639\u0631',
  '\u0631\u0634\u062d',
  '\u0631\u0634\u062d\u0644\u064a',
  '\u0637\u064a\u0628',
  '\u0628\u0633',
};

class AvailabilityFollowUpSignal {
  final bool hasSimilarityTerm;
  final bool hasCheaperTerm;
  final bool hasContextRef;
  final bool hasExplicitAvailabilityProduct;

  const AvailabilityFollowUpSignal({
    required this.hasSimilarityTerm,
    required this.hasCheaperTerm,
    required this.hasContextRef,
    required this.hasExplicitAvailabilityProduct,
  });

  bool get isContextualSimilarityFollowUp =>
      hasSimilarityTerm && !hasExplicitAvailabilityProduct;

  bool get isContextualSimilarCheaperPivotCandidate =>
      hasSimilarityTerm &&
      hasCheaperTerm &&
      hasContextRef &&
      !hasExplicitAvailabilityProduct;

  bool get isContextualCheaperPivotCandidate =>
      hasCheaperTerm && hasContextRef && !hasExplicitAvailabilityProduct;
}

String _normalizeAvailabilityText(String text) {
  return AIChatTextNormalizer.normalizeForParsing(text);
}

AvailabilityFollowUpSignal analyzeAvailabilityFollowUpSignal(String message) {
  final normalized = _normalizeAvailabilityText(message);
  if (normalized.isEmpty) {
    return const AvailabilityFollowUpSignal(
      hasSimilarityTerm: false,
      hasCheaperTerm: false,
      hasContextRef: false,
      hasExplicitAvailabilityProduct: false,
    );
  }

  final extractedCandidate =
      AvailabilityIntentUtils.extractAvailabilityProductQuery(message);
  final hasExplicitAvailabilityProduct =
      extractedCandidate != null &&
      isConcreteAvailabilityProductReference(extractedCandidate);

  return AvailabilityFollowUpSignal(
    hasSimilarityTerm: _containsAnyTerm(normalized, _similarityTerms),
    hasCheaperTerm: _containsAnyTerm(normalized, _cheaperTerms),
    hasContextRef: _looksLikeImplicitContextReference(normalized),
    hasExplicitAvailabilityProduct: hasExplicitAvailabilityProduct,
  );
}

bool looksLikeAvailabilityFollowUp(String message) {
  final normalized = _normalizeAvailabilityText(message);
  for (final keyword in _availabilityFollowUpKeywords) {
    if (normalized.contains(_normalizeAvailabilityText(keyword))) {
      return true;
    }
  }
  return false;
}

bool looksLikeContextualAvailabilityFollowUp(String message) {
  final signal = analyzeAvailabilityFollowUpSignal(message);
  return signal.hasContextRef &&
      (signal.hasSimilarityTerm || signal.hasCheaperTerm);
}

bool prefersCheaperAvailabilityAlternative(String message) {
  final signal = analyzeAvailabilityFollowUpSignal(message);
  return signal.hasCheaperTerm;
}

bool looksLikeProductWhyFollowUp(String message) {
  final normalized = AIChatTextNormalizer.normalizeForParsing(message);
  if (normalized.isEmpty) return false;
  final asksWhy =
      normalized.contains('why') ||
      _containsBoundedPhrase(
        normalized,
        '\u0627\u0634\u0645\u0639\u0646\u0627',
      ) ||
      _containsBoundedPhrase(normalized, '\u0644\u064a\u0647') ||
      _containsBoundedPhrase(
        normalized,
        '\u0639\u0634\u0627\u0646 \u0627\u064a\u0647',
      ) ||
      _containsBoundedPhrase(
        normalized,
        '\u0639\u0634\u0627\u0646 \u0627\u064a',
      );
  final asksForReason =
      normalized.contains('good') ||
      normalized.contains('recommended') ||
      normalized.contains('suggested') ||
      normalized.contains('\u062d\u0644\u0648') ||
      normalized.contains('\u0643\u0648\u064a\u0633');
  return asksWhy || asksForReason;
}

bool looksLikeProductDetailsFollowUp(String message) {
  final normalized = AIChatTextNormalizer.normalizeForParsing(message);
  if (normalized.isEmpty) return false;
  return normalized.contains('tell me more') ||
      normalized.contains('more about') ||
      normalized.contains('details about') ||
      normalized.contains('tell me about') ||
      normalized.contains('\u0627\u062e\u0628\u0631\u0646\u064a') ||
      normalized.contains(
        '\u0642\u0648\u0644\u064a \u0627\u0643\u062a\u0631',
      ) ||
      normalized.contains('\u062a\u0641\u0627\u0635\u064a\u0644') ||
      normalized.contains('\u0627\u0643\u062b\u0631 \u0639\u0646');
}

bool _containsAnyTerm(String normalized, Set<String> terms) {
  for (final term in terms) {
    final normalizedTerm = _normalizeAvailabilityText(term);
    if (normalized.contains(normalizedTerm)) {
      return true;
    }
  }
  return false;
}

bool _containsBoundedPhrase(String normalized, String phrase) {
  final normalizedPhrase = _normalizeAvailabilityText(phrase);
  if (normalizedPhrase.isEmpty) return false;
  final pattern =
      r'(^|[\s،,.!?؟؛:])' +
      RegExp.escape(normalizedPhrase) +
      r'(?=$|[\s،,.!?؟؛:])';
  return RegExp(pattern).hasMatch(normalized);
}

bool _looksLikeImplicitContextReference(String normalized) {
  if (_containsAnyTerm(normalized, _contextReferenceTerms)) {
    return true;
  }

  return normalized.contains('like it') ||
      normalized.contains('like this') ||
      normalized.contains('\u0632\u064a\u0647') ||
      normalized.contains('\u0645\u0634\u0627\u0628\u0647');
}

bool isConcreteAvailabilityProductReference(String candidate) {
  final normalizedCandidate = _normalizeAvailabilityText(candidate);
  if (normalizedCandidate.isEmpty) return false;

  final tokens = normalizedCandidate
      .split(RegExp(r'\s+'))
      .where((token) => token.trim().length >= 2)
      .toList(growable: false);
  if (tokens.isEmpty) return false;

  final meaningfulTokens = tokens
      .where((token) => !_nonConcreteAvailabilityTokens.contains(token))
      .toList(growable: false);

  if (meaningfulTokens.isEmpty) return false;
  return meaningfulTokens.any((token) => token.length >= 3);
}
