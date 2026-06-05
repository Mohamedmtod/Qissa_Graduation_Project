import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_matchers.dart'
    as parser_matchers;

class BudgetAmountParser {
  static final RegExp _numberPattern = RegExp(
    r'(?<![a-z0-9])(\d{1,6}(?:[.,]\d{1,3})?)(?:\s*k)?(?![a-z0-9])',
  );

  static const Set<String> _ageTerms = {
    'year old',
    'years old',
    'yr old',
    'yrs old',
    'age',
    'old',
  };

  static double? extractMaxBudget(
    String normalizedMessage, {
    required double? currentBudget,
    required Set<String> budgetContextKeywords,
    required Set<String> cheapKeywords,
  }) {
    final message = _normalizeDigits(normalizedMessage);

    final matches = _numberPattern.allMatches(message).toList();
    if (matches.isNotEmpty) {
      final hasRangeIndicator =
          RegExp(
            r'\b(to|and|between|من|ل|الي|إلى|و|بين)\b',
          ).hasMatch(message) ||
          message.contains('رينج') ||
          message.contains('رينج') ||
          message.contains(' ل ') ||
          message.contains(' range ') ||
          message.contains('ل ') ||
          message.contains(' ل') ||
          message.contains('-') ||
          message.contains('~');
      final candidates = <_BudgetCandidate>[];
      for (final match in matches) {
        final candidate = _candidateFromMatch(
          message,
          match,
          budgetContextKeywords: budgetContextKeywords,
        );
        if (candidate != null) candidates.add(candidate);
      }

      if (candidates.isNotEmpty) {
        if (hasRangeIndicator && candidates.length >= 2) {
          candidates.sort((a, b) => a.value.compareTo(b.value));
          return candidates.last.value;
        }
        if (_looksLikeRejectedAlternativeAmount(message) &&
            candidates.length >= 2) {
          candidates.sort((a, b) => a.start.compareTo(b.start));
          return candidates.first.value;
        }
        if (_looksLikeForbiddenUpsellReference(message) &&
            candidates.length >= 2) {
          return candidates.first.value;
        }
        final contextualCandidates = candidates
            .where((candidate) => candidate.hasExplicitBudgetContext)
            .toList(growable: false);
        if (contextualCandidates.isNotEmpty) {
          return contextualCandidates.last.value;
        }
        if (candidates.length >= 2) {
          candidates.sort((a, b) => a.value.compareTo(b.value));
          return candidates.first.value;
        }
        return candidates.single.value;
      }
    }

    if (_looksLikeBudgetClearCommand(message)) {
      return null;
    }

    if (currentBudget != null &&
        cheapKeywords.any(
          (keyword) =>
              parser_matchers.findTermMatches(message, keyword).isNotEmpty,
        )) {
      return currentBudget * 0.85;
    }

    return null;
  }

  static bool _looksLikeForbiddenUpsellReference(String message) {
    final normalized = _normalizeDigits(message).toLowerCase();
    final hasBlockCue =
        normalized.contains('do not show') ||
        normalized.contains("don't show") ||
        normalized.contains('dont show') ||
        normalized.contains('not show') ||
        normalized.contains(
          '\u0645\u062a\u0637\u0644\u0639\u0647\u0627\u0634',
        ) ||
        normalized.contains(
          '\u0645\u0627 \u062a\u0637\u0644\u0639\u0647\u0627\u0634',
        ) ||
        normalized.contains(
          '\u0645\u062a\u0639\u0631\u0636\u0647\u0627\u0634',
        ) ||
        normalized.contains(
          '\u0645\u0627 \u062a\u0639\u0631\u0636\u0647\u0627\u0634',
        );
    if (!hasBlockCue) return false;

    return normalized.contains('better') ||
        normalized.contains('above') ||
        normalized.contains('over') ||
        normalized.contains('\u0627\u062d\u0633\u0646') ||
        normalized.contains('\u0623\u062d\u0633\u0646') ||
        normalized.contains('\u0641\u0648\u0642') ||
        normalized.contains('\u0627\u0639\u0644\u0649') ||
        normalized.contains('\u0623\u0639\u0644\u0649');
  }

  static bool _looksLikeRejectedAlternativeAmount(String message) {
    final normalized = _normalizeDigits(message).toLowerCase();
    return RegExp(
      r'\b(?:no|not|not\s+over|not\s+above|not\s+more\s+than)\s+\d',
    ).hasMatch(normalized);
  }

  static bool containsBudgetNumber(String normalizedMessage) {
    return _numberPattern.hasMatch(_normalizeDigits(normalizedMessage));
  }

  static _BudgetCandidate? _candidateFromMatch(
    String message,
    RegExpMatch match, {
    required Set<String> budgetContextKeywords,
  }) {
    final raw = match.group(0) ?? '';
    final numericRaw = match.group(1) ?? '';
    final value = _parseNumber(numericRaw);
    if (value == null) return null;

    // Keep a wider window so phrases like "under 700 EGP. Do not show anything
    // above budget" still count as explicit budget context.
    final windowStart = (match.start - 40).clamp(0, message.length);
    final windowEnd = (match.end + 40).clamp(0, message.length);
    final around = message.substring(windowStart, windowEnd);

    final hasAgeContext = _ageTerms.any((keyword) => around.contains(keyword));
    if (hasAgeContext) return null;
    if (_looksLikeCountRequestNumber(message, match, value)) return null;

    final hasBudgetContext = budgetContextKeywords.any(
      (keyword) => parser_matchers.findTermMatches(around, keyword).isNotEmpty,
    );
    final hasCurrencyContext =
        around.contains('egp') ||
        around.contains('جنيه') ||
        around.contains('جنية') ||
        around.contains('pound') ||
        around.contains('pounds') ||
        around.contains('budget') ||
        around.contains('under') ||
        around.contains('below') ||
        around.contains('around');
    final hasKMultiplier = raw.trim().toLowerCase().endsWith('k');
    final effectiveValue = hasKMultiplier ? value * 1000 : value;
    final hasExplicitBudgetContext = hasBudgetContext || hasCurrencyContext;

    if (hasExplicitBudgetContext || effectiveValue >= 100) {
      return _BudgetCandidate(
        effectiveValue,
        start: match.start,
        hasExplicitBudgetContext: hasExplicitBudgetContext,
      );
    }
    return null;
  }

  static bool _looksLikeCountRequestNumber(
    String message,
    RegExpMatch match,
    double value,
  ) {
    if (value < 1 || value > 20 || value != value.roundToDouble()) {
      return false;
    }

    final beforeStart = (match.start - 18).clamp(0, message.length);
    final afterEnd = (match.end + 32).clamp(0, message.length);
    final before = message.substring(beforeStart, match.start);
    final after = message.substring(match.end, afterEnd);
    final around =
        '$before ${message.substring(match.start, match.end)} $after';

    final afterLooksLikeItemCount = RegExp(
      r'^\s*(?:male\s+|men\s+|mens\s+|women\s+|female\s+|summer\s+|winter\s+|fresh\s+|cheap\s+|affordable\s+){0,6}'
      r'(?:perfumes?|fragrances?|scents?|options?|choices?|recommendations?|picks?)\b',
      caseSensitive: false,
    ).hasMatch(after);
    if (afterLooksLikeItemCount) return true;

    final beforeLooksLikeCountCommand = RegExp(
      r'\b(?:top|show|give|recommend|suggest|pick|choose|عايز|عايزة|رشح|رشحلي|هات)\s*$',
      caseSensitive: false,
    ).hasMatch(before);
    final aroundHasCountNoun = RegExp(
      r'\b(?:perfumes?|fragrances?|scents?|options?|choices?|recommendations?|picks?)\b',
      caseSensitive: false,
    ).hasMatch(around);
    return beforeLooksLikeCountCommand && aroundHasCountNoun;
  }

  static double? _parseNumber(String raw) {
    var normalized = _normalizeDigits(raw).trim();
    if (normalized.isEmpty) return null;
    normalized = normalized.replaceAll(RegExp(r'[^0-9.,]'), '');
    normalized = normalized.replaceAll(RegExp(r'[.,]+$'), '');
    if (normalized.isEmpty) return null;

    final separatorMatches = RegExp(r'[.,]').allMatches(normalized).toList();
    if (separatorMatches.isEmpty) {
      return double.tryParse(normalized);
    }

    final parts = normalized.split(RegExp(r'[.,]'));
    final looksLikeThousands =
        parts.length >= 2 &&
        parts.first.length <= 3 &&
        parts.skip(1).every((part) => part.length == 3);
    if (looksLikeThousands) {
      return double.tryParse(parts.join());
    }

    if (separatorMatches.length == 1 && parts.length == 2) {
      final fraction = parts.last;
      if (fraction.length <= 2) {
        return double.tryParse('${parts.first}.$fraction');
      }
    }

    return double.tryParse(parts.join());
  }

  static String _normalizeDigits(String input) {
    const digits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    var result = input;
    for (final entry in digits.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static bool _looksLikeBudgetClearCommand(String message) {
    final normalized = _normalizeDigits(message).toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('forget budget') ||
        normalized.contains('remove budget') ||
        normalized.contains('clear budget') ||
        normalized.contains('no budget') ||
        normalized.contains('without budget') ||
        normalized.contains('open budget') ||
        normalized.contains('budget open') ||
        normalized.contains('no budget limit') ||
        normalized.contains('no limit') ||
        normalized.contains('unlimited') ||
        normalized.contains('money is not a problem');
  }
}

class _BudgetCandidate {
  final double value;
  final int start;
  final bool hasExplicitBudgetContext;

  const _BudgetCandidate(
    this.value, {
    required this.start,
    required this.hasExplicitBudgetContext,
  });
}
