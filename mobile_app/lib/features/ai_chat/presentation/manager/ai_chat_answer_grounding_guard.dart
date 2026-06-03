import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatAnswerGroundingDecision {
  final bool isAllowed;
  final String? reasonCode;

  const AIChatAnswerGroundingDecision._({
    required this.isAllowed,
    required this.reasonCode,
  });

  const AIChatAnswerGroundingDecision.allowed()
    : this._(isAllowed: true, reasonCode: null);

  const AIChatAnswerGroundingDecision.blocked(String reasonCode)
    : this._(isAllowed: false, reasonCode: reasonCode);
}

class AIChatAnswerGroundingGuard {
  static final RegExp _pricePattern = RegExp(
    r'(?:egp|جنيه|price|cost|costs|سعر|بـ|ب)\s*([0-9]+(?:\.[0-9]+)?)|([0-9]+(?:\.[0-9]+)?)\s*(?:egp|جنيه)',
    caseSensitive: false,
  );

  static const Set<String> _claimableNotes = {
    'amber',
    'apple',
    'aquatic',
    'bergamot',
    'cedar',
    'cinnamon',
    'citrus',
    'floral',
    'jasmine',
    'lavender',
    'leather',
    'lemon',
    'musk',
    'oud',
    'patchouli',
    'pepper',
    'pineapple',
    'rose',
    'sandalwood',
    'smoky',
    'spicy',
    'sweet',
    'tobacco',
    'tonka',
    'vanilla',
    'woody',
  };

  const AIChatAnswerGroundingGuard();

  AIChatAnswerGroundingDecision validate({
    required AIChatReply reply,
    required List<ProductModel> localFacts,
    SessionPreferences effectivePreferences = const SessionPreferences(),
  }) {
    if (!reply.isAnswer) {
      return const AIChatAnswerGroundingDecision.allowed();
    }
    if (reply.productIds.isNotEmpty) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_contains_product_ids',
      );
    }

    final answer = reply.answer?.trim() ?? '';
    if (answer.isEmpty) {
      return const AIChatAnswerGroundingDecision.blocked('answer_empty');
    }

    final lower = answer.toLowerCase();
    if (_containsInternalLeakage(lower)) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_internal_leakage',
      );
    }
    final excludedDecision = _validateExcludedNotes(
      lower,
      effectivePreferences,
    );
    if (!excludedDecision.isAllowed) return excludedDecision;

    final hasGroundedFacts = localFacts.isNotEmpty;
    if (!hasGroundedFacts && _containsFactualProductClaim(lower)) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_has_no_local_facts',
      );
    }

    final priceDecision = _validatePrices(lower, localFacts);
    if (!priceDecision.isAllowed) return priceDecision;

    final noteDecision = _validateNotes(lower, localFacts);
    if (!noteDecision.isAllowed) return noteDecision;

    return const AIChatAnswerGroundingDecision.allowed();
  }

  AIChatAnswerGroundingDecision _validateExcludedNotes(
    String lower,
    SessionPreferences preferences,
  ) {
    final excluded = {
      ...preferences.excludedNotes,
      ...preferences.medicalExcludedNotes,
    };
    for (final note in excluded) {
      for (final alias in _noteAliases(note)) {
        if (alias.isEmpty) continue;
        if (RegExp(
          r'(^|[^a-z])' + RegExp.escape(alias) + r'([^a-z]|$)',
        ).hasMatch(lower)) {
          return const AIChatAnswerGroundingDecision.blocked(
            'answer_mentions_excluded_note',
          );
        }
      }
    }
    return const AIChatAnswerGroundingDecision.allowed();
  }

  Set<String> _noteAliases(String note) {
    switch (note.toLowerCase().trim()) {
      case 'vanilla':
        return const {
          'vanilla',
          '\u0641\u0627\u0646\u064a\u0644\u064a\u0627',
          '\u0627\u0644\u0641\u0627\u0646\u064a\u0644\u064a\u0627',
        };
      case 'rose':
        return const {
          'rose',
          '\u0648\u0631\u062f',
          '\u0627\u0644\u0648\u0631\u062f',
        };
      case 'jasmine':
        return const {
          'jasmine',
          '\u064a\u0627\u0633\u0645\u064a\u0646',
          '\u0627\u0644\u064a\u0627\u0633\u0645\u064a\u0646',
        };
      case 'citrus':
        return const {
          'citrus',
          'lemon',
          'bergamot',
          'orange',
          '\u062d\u0645\u0636\u064a\u0627\u062a',
          '\u062d\u0645\u0636\u064a',
          '\u0644\u064a\u0645\u0648\u0646',
          '\u0628\u0631\u063a\u0645\u0648\u062a',
          '\u0628\u0631\u062a\u0642\u0627\u0644',
        };
    }
    return {note.toLowerCase().trim()};
  }

  bool _containsFactualProductClaim(String lower) {
    return lower.contains('egp') ||
        lower.contains('جنيه') ||
        lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('available') ||
        lower.contains('in stock') ||
        lower.contains('out of stock') ||
        lower.contains('متوفر') ||
        lower.contains('موجود') ||
        lower.contains('غير متوفر') ||
        lower.contains('notes') ||
        lower.contains('smells like') ||
        lower.contains('سعر') ||
        lower.contains('نوتات');
  }

  bool _containsInternalLeakage(String lower) {
    return lower.contains('system prompt') ||
        lower.contains('developer message') ||
        lower.contains('internal prompt') ||
        lower.contains('json schema') ||
        lower.contains('schema version') ||
        lower.contains('schema') ||
        lower.contains('نموذج json داخلي') ||
        lower.contains('تعليمات النظام') ||
        lower.contains('رسالة المطور');
  }

  AIChatAnswerGroundingDecision _validatePrices(
    String lower,
    List<ProductModel> localFacts,
  ) {
    final matches = _pricePattern.allMatches(lower).toList(growable: false);
    if (matches.isEmpty) {
      return const AIChatAnswerGroundingDecision.allowed();
    }
    if (localFacts.isEmpty) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_price_without_facts',
      );
    }

    final allowedPrices = localFacts
        .map((product) => product.effectivePrice.round())
        .toSet();
    for (final match in matches) {
      final raw = match.group(1) ?? match.group(2);
      final value = double.tryParse(raw ?? '')?.round();
      if (value == null || !allowedPrices.contains(value)) {
        return const AIChatAnswerGroundingDecision.blocked(
          'answer_unsupported_price',
        );
      }
    }
    return const AIChatAnswerGroundingDecision.allowed();
  }

  AIChatAnswerGroundingDecision _validateNotes(
    String lower,
    List<ProductModel> localFacts,
  ) {
    if (!_looksLikeNoteClaim(lower)) {
      return const AIChatAnswerGroundingDecision.allowed();
    }

    final mentionedNotes = _claimableNotes
        .where((note) => RegExp('\\b$note\\b').hasMatch(lower))
        .toSet();
    if (mentionedNotes.isEmpty) {
      return const AIChatAnswerGroundingDecision.allowed();
    }
    if (localFacts.isEmpty) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_note_without_facts',
      );
    }

    final allowedNotes = <String>{};
    for (final product in localFacts) {
      allowedNotes.addAll(_tokenize(product.fragranceFamily));
      allowedNotes.addAll(_tokenize(product.description));
      allowedNotes.addAll(product.notes.expand(_tokenize));
      allowedNotes.addAll(product.topNotes.expand(_tokenize));
      allowedNotes.addAll(product.middleNotes.expand(_tokenize));
      allowedNotes.addAll(product.baseNotes.expand(_tokenize));
      allowedNotes.addAll(product.tags.expand(_tokenize));
    }

    final unsupported = mentionedNotes.difference(allowedNotes);
    if (unsupported.isNotEmpty) {
      return const AIChatAnswerGroundingDecision.blocked(
        'answer_unsupported_note',
      );
    }
    return const AIChatAnswerGroundingDecision.allowed();
  }

  bool _looksLikeNoteClaim(String lower) {
    return lower.contains('note') ||
        lower.contains('notes') ||
        lower.contains('has ') ||
        lower.contains('with ') ||
        lower.contains('smells like') ||
        lower.contains('scent');
  }

  Iterable<String> _tokenize(String value) sync* {
    for (final token in value.toLowerCase().split(RegExp(r'[^a-z]+'))) {
      if (token.isNotEmpty) yield token;
    }
  }
}
