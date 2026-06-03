import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

class AIChatRecommendationSelectionResult {
  const AIChatRecommendationSelectionResult({
    required this.matches,
    this.isAmbiguous = false,
  });

  final List<RecommendedProductRef> matches;
  final bool isAmbiguous;
}

class AIChatRecommendationSelectionResolver {
  const AIChatRecommendationSelectionResolver();

  AIChatRecommendationSelectionResult? resolve(
    String normalized,
    List<RecommendedProductRef> refs, {
    List<AIChatMessage> messages = const [],
    bool allowNameOnly = false,
  }) {
    final byIndex = selectedIndexes(normalized, refs.length);
    if (byIndex.isNotEmpty) {
      return AIChatRecommendationSelectionResult(
        matches: byIndex.map((index) => refs[index]).toList(growable: false),
      );
    }

    if (looksLikeCartSelection(normalized)) {
      final recentSelection = resolveRecentMentionedRecommendations(
        refs,
        messages,
      );
      if (recentSelection.isNotEmpty) {
        return AIChatRecommendationSelectionResult(
          matches: recentSelection,
          isAmbiguous: recentSelection.length > 2,
        );
      }
      if (refs.isNotEmpty) {
        return AIChatRecommendationSelectionResult(matches: [refs.first]);
      }
    }

    if (!looksLikeSelectionIntent(normalized) && !allowNameOnly) {
      return null;
    }

    final nameMatches = refs
        .where((ref) {
          final terms =
              <String>[ref.name, ref.brand, '${ref.brand} ${ref.name}']
                  .map(LocalIntentParser.normalizeInput)
                  .where((term) => term.length >= 3);
          return terms.any((term) {
            if (normalized == term) return true;
            if (normalized.contains(term)) return true;
            return term
                .split(RegExp(r'\s+'))
                .where((token) => token.length >= 4)
                .any(normalized.contains);
          });
        })
        .toList(growable: false);

    if (nameMatches.isEmpty) return null;
    if (nameMatches.length == 1) {
      return AIChatRecommendationSelectionResult(matches: nameMatches);
    }
    return AIChatRecommendationSelectionResult(
      matches: nameMatches,
      isAmbiguous: true,
    );
  }

  List<RecommendedProductRef> resolveRecentMentionedRecommendations(
    List<RecommendedProductRef> refs,
    List<AIChatMessage> messages,
  ) {
    for (final message in messages.reversed) {
      if (message.isFromUser || message.isLoading) continue;
      final normalizedContent = LocalIntentParser.normalizeInput(
        message.content,
      );
      if (normalizedContent.isEmpty) continue;

      final matches = refs
          .where((ref) => _messageMentionsRef(normalizedContent, ref))
          .toList(growable: false);
      if (matches.isNotEmpty) return matches;

      if (message.isRecommendation || message.isAvailability) break;
    }
    return const [];
  }

  Set<int> selectedIndexes(String normalized, int maxCount) {
    final indexes = <int>{};
    if (_hasFirstTwo(normalized)) {
      if (maxCount >= 1) indexes.add(0);
      if (maxCount >= 2) indexes.add(1);
      return indexes;
    }

    if (_hasFirst(normalized) && maxCount >= 1) indexes.add(0);
    if (_hasSecond(normalized) && maxCount >= 2) indexes.add(1);
    if (_hasThird(normalized) && maxCount >= 3) indexes.add(2);
    return indexes;
  }

  bool looksLikeSelectionIntent(String normalized) {
    return normalized.contains('want') ||
        normalized.contains('take') ||
        normalized.contains('get') ||
        normalized.contains('choose') ||
        normalized.contains('add') ||
        normalized.contains('cart') ||
        normalized.contains('details') ||
        _containsAnyNormalized(normalized, const [
          '\u0639\u0627\u064a\u0632',
          '\u0639\u0627\u0648\u0632\u0647',
          '\u0639\u0627\u0648\u0632',
          '\u0647\u0627\u062a',
          '\u062e\u062f',
          '\u0627\u062e\u062a\u0627\u0631',
          '\u0636\u064a\u0641',
          '\u0627\u0636\u0641\u0647',
          '\u0623\u0636\u0641\u0647',
          '\u0627\u0644\u0633\u0644\u0629',
          '\u0644\u0644\u0633\u0644\u0629',
          '\u0627\u0644\u0643\u0627\u0631\u062a',
          '\u062a\u0641\u0627\u0635\u064a\u0644',
        ]);
  }

  bool looksLikeCartSelection(String normalized) {
    return normalized.contains('cart') ||
        normalized.contains('basket') ||
        normalized.contains('add') ||
        _containsAnyNormalized(normalized, const [
          '\u0627\u0644\u0633\u0644\u0629',
          '\u0627\u0644\u0633\u0644\u0647',
          '\u0627\u0644\u0643\u0627\u0631\u062a',
          '\u0627\u0636\u0641',
          '\u0623\u0636\u0641',
          '\u0627\u0636\u0641\u0647',
          '\u0623\u0636\u0641\u0647',
          '\u0636\u064a\u0641',
          '\u062d\u0637',
          '\u0644\u0644\u0633\u0644\u0629',
        ]);
  }

  bool _hasFirstTwo(String normalized) {
    return normalized.contains('first two') ||
        normalized.contains('1 and 2') ||
        normalized.contains('one and two') ||
        normalized.contains('both') ||
        normalized.contains('the two') ||
        _containsAnyNormalized(normalized, const [
          '\u0627\u0648\u0644 \u0627\u062a\u0646\u064a\u0646',
          '\u0627\u0648\u0644 \u0627\u062b\u0646\u064a\u0646',
          '\u0627\u0644\u0627\u062a\u0646\u064a\u0646',
          '\u0627\u0644\u0627\u062b\u0646\u064a\u0646',
          '\u0627\u0644\u0627\u0648\u0644 \u0648\u0627\u0644\u062a\u0627\u0646\u064a',
          '\u0627\u0644\u0627\u0648\u0644 \u0648\u0627\u0644\u062b\u0627\u0646\u064a',
        ]);
  }

  bool _hasFirst(String normalized) {
    return RegExp(r'\b(first|#?1)\b').hasMatch(normalized) ||
        (RegExp(r'\bone\b').hasMatch(normalized) &&
            !RegExp(
              r'\b(second|third|two|three)\s+one\b',
            ).hasMatch(normalized)) ||
        _containsAnyNormalized(normalized, const [
          '\u0627\u0644\u0627\u0648\u0644',
          '\u0627\u0644\u0623\u0648\u0644',
          '\u0627\u0648\u0644\u0627\u0646\u064a',
          '\u0623\u0648\u0644\u0627\u0646\u064a',
          '\u0627\u0648\u0644 \u0648\u0627\u062d\u062f',
          '\u0623\u0648\u0644 \u0648\u0627\u062d\u062f',
        ]);
  }

  bool _hasSecond(String normalized) {
    return RegExp(r'\b(second|two|#?2)\b').hasMatch(normalized) ||
        _containsAnyNormalized(normalized, const [
          '\u0627\u0644\u062a\u0627\u0646\u064a',
          '\u0627\u0644\u062b\u0627\u0646\u064a',
          '\u062a\u0627\u0646\u064a \u0648\u0627\u062d\u062f',
          '\u062b\u0627\u0646\u064a \u0648\u0627\u062d\u062f',
        ]);
  }

  bool _hasThird(String normalized) {
    return RegExp(r'\b(third|three|#?3)\b').hasMatch(normalized) ||
        _containsAnyNormalized(normalized, const [
          '\u0627\u0644\u062a\u0627\u0644\u062a',
          '\u0627\u0644\u062b\u0627\u0644\u062b',
          '\u062a\u0627\u0644\u062a \u0648\u0627\u062d\u062f',
          '\u062b\u0627\u0644\u062b \u0648\u0627\u062d\u062f',
        ]);
  }

  bool _messageMentionsRef(
    String normalizedContent,
    RecommendedProductRef ref,
  ) {
    final terms = <String>[
      ref.name,
      '${ref.brand} ${ref.name}',
    ].map(LocalIntentParser.normalizeInput).where((term) => term.length >= 4);
    return terms.any(normalizedContent.contains);
  }

  bool _containsAnyNormalized(String normalized, Iterable<String> terms) {
    return terms.map(LocalIntentParser.normalizeInput).any(normalized.contains);
  }
}
