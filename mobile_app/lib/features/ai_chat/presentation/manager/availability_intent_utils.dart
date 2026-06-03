import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';

// Availability intent helpers keep exact catalog availability local and
// separate it from recommendation/refinement requests.

class AvailabilityIntentUtils {
  static final Set<String> availabilityKeywords = <String>{
    '\u0641\u064a\u0647',
    '\u0639\u0646\u062f\u0643',
    '\u0639\u0646\u062f\u0643\u0645',
    '\u0645\u062a\u0648\u0641\u0631',
    '\u0645\u062a\u0648\u0641\u0631\u0629',
    '\u0645\u062a\u0648\u0641\u0631\u0647',
    '\u0645\u0648\u062c\u0648\u062f',
    '\u0645\u0648\u062c\u0648\u062f\u0629',
    '\u0645\u0648\u062c\u0648\u062f\u0647',
    '\u0645\u062a\u0627\u062d',
    '\u0645\u062a\u0627\u062d\u0629',
    '\u0645\u062a\u0627\u062d\u0647',
    '\u0644\u0633\u0647 \u0645\u0648\u062c\u0648\u062f',
    'available',
    'availble',
    'avialable',
    'in stock',
    'do you have',
    'is there',
    'is this available',
    'is that available',
    'is it available',
    'have this',
  };

  static final Set<String> availabilityNoisePhrases = <String>{
    '\u0647\u0644',
    '\u0645\u0645\u0643\u0646',
    '\u0644\u0648 \u0633\u0645\u062d\u062a',
    '\u0645\u0646 \u0641\u0636\u0644\u0643',
    '\u0639\u0627\u064a\u0632 \u0627\u0639\u0631\u0641',
    '\u0639\u0627\u064a\u0632\u0629 \u0627\u0639\u0631\u0641',
    '\u0639\u0627\u064a\u0632\u0647 \u0627\u0639\u0631\u0641',
    'i need to know',
    'can you tell me',
    'do you have',
    'is there',
    'is it',
    'is this',
  };

  static const Set<String> _nicheScentAvailabilityTerms = {
    'petrichor',
    'rain on soil',
    'wet soil',
    'rain smell',
    'smell of rain',
    'earthy rain',
  };

  static const Set<String> recommendationRejectionKeywords = {
    'no',
    'not those',
    'dont want those',
    'do not want those',
    'not these',
    'different one',
    'another one',
    '\u0645\u0634 \u0639\u0627\u064a\u0632 \u062f\u0648\u0644',
    '\u0644\u0627 \u0645\u0634 \u062f\u0648\u0644',
    '\u0645\u0634 \u062f\u0648\u0644',
    '\u0645\u0634 \u0639\u0627\u064a\u0632\u0647\u0645',
    '\u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629 \u062a\u0627\u0646\u064a\u0629',
    '\u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0647 \u062a\u0627\u0646\u064a\u0647',
    '\u0644\u0627 \u0639\u0627\u064a\u0632',
    '\u0645\u0634 \u062f\u0647',
    '\u0645\u0634 \u062f\u0627',
  };

  static final Set<String> availabilityStopwords = <String>{
    '\u0647\u0644',
    '\u0641\u064a\u0647',
    '\u0641\u064a',
    '\u0645\u0646',
    '\u0627\u0644',
    '\u0639\u0637\u0631',
    '\u0628\u0631\u0641\u0627\u0646',
    '\u0627\u0644\u0639\u0637\u0631',
    '\u0627\u0644\u0628\u0631\u0641\u0627\u0646',
    '\u0627\u0644\u0645\u062a\u0648\u0641\u0631',
    '\u0645\u062a\u0648\u0641\u0631',
    '\u0645\u062a\u0648\u0641\u0631\u0629',
    '\u0645\u062a\u0648\u0641\u0631\u0647',
    '\u0645\u0648\u062c\u0648\u062f',
    '\u0645\u0648\u062c\u0648\u062f\u0629',
    '\u0645\u0648\u062c\u0648\u062f\u0647',
    '\u0645\u062a\u0627\u062d',
    '\u0645\u062a\u0627\u062d\u0629',
    '\u0645\u062a\u0627\u062d\u0647',
    '\u0639\u0646\u062f\u0643',
    '\u0639\u0646\u062f\u0643\u0645',
    '\u0633\u0639\u0631',
    '\u0627\u0644\u0633\u0639\u0631',
    '\u0628\u0643\u0627\u0645',
    '\u0628\u0643\u0645',
    '\u0643\u0627\u0645',
    '\u0643\u0645',
    'please',
    'perfume',
    'fragrance',
    'available',
    'stock',
    'but',
    'lower',
    'in',
    'is',
    'it',
    'this',
    'that',
    'do',
    'have',
    'a',
    'an',
    'the',
    'price',
    'cost',
    'how',
    'much',
  };

  static const Set<String> contextualAvailabilityFollowUpPhrases = {
    '\u0639\u0646\u062f\u0643 \u0645\u0646\u0647',
    '\u0647\u0644 \u0645\u062a\u0648\u0641\u0631',
    '\u0647\u0644 \u0645\u062a\u0627\u062d',
    '\u0645\u062a\u0648\u0641\u0631',
    '\u0645\u062a\u0627\u062d',
    'do you have it',
    'is it available',
  };

  static const Set<String> genericAvailabilityCandidateFillers = {
    '\u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0647',
    '\u0639\u0627\u064a\u0632 \u062d\u0627\u062c\u0629',
    '\u0647\u0627\u062a\u0644\u064a',
    '\u0639\u0637\u0631',
    '\u0627\u064a \u0639\u0637\u0631',
    '\u0623\u064a \u0639\u0637\u0631',
  };

  static const Set<String> genericSimilarityFollowUpTokens = {
    'actually',
    'give',
    'show',
    'me',
    'one',
    'something',
    'any',
    'recommend',
    'recommendation',
    'best',
    'match',
    'option',
    'make',
    'strictly',
    'your',
    'similar',
    'alternative',
    'closest',
    'available',
    'but',
    'lower',
    'price',
    'like',
    'it',
    'this',
    'that',
    'to',
    'for',
    'please',
    'can',
    'could',
    'would',
    'u',
    '\u062d\u0627\u062c\u0647',
    '\u062d\u0627\u062c\u0629',
    '\u0627\u064a',
    '\u0627\u064a\u0647',
    '\u0637\u0628',
    '\u0637\u064a\u0628',
    '\u0631\u0634\u062d',
    '\u0631\u0634\u062d\u0644\u064a',
    '\u0639\u0627\u064a\u0632',
    '\u0639\u0627\u064a\u0632\u0647',
    '\u0639\u0627\u0648\u0632',
    '\u0639\u0627\u0648\u0632\u0647',
    '\u0647\u0627\u062a\u0644\u064a',
    '\u0634\u0628\u0647\u0647',
    '\u0632\u064a\u0647',
    '\u0645\u0634\u0627\u0628\u0647',
    '\u0628\u062f\u064a\u0644',
    '\u0628\u062f\u064a\u0644\u0647',
    '\u0648\u0627\u062d\u062f',
    '\u0648\u0627\u062d\u062f\u0629',
    '\u0628\u0633',
    '\u0627\u0631\u062e\u0635',
    '\u0623\u0631\u062e\u0635',
    '\u0627\u0642\u0644',
    '\u0633\u0639\u0631',
  };

  static const Set<String> _standalonePerfumeNameBlockedTokens = {
    'aquatic',
    'aromatic',
    'amber',
    'budget',
    'cheap',
    'cheaper',
    'citrus',
    'clean',
    'daily',
    'date',
    'elegant',
    'floral',
    'formal',
    'fresh',
    'fragrance',
    'gym',
    'heavy',
    'leather',
    'light',
    'medium',
    'musk',
    'musky',
    'office',
    'oud',
    'perfume',
    'powdery',
    'rose',
    'smoky',
    'spicy',
    'sporty',
    'strong',
    'summer',
    'sweet',
    'university',
    'vanilla',
    'winter',
    'woody',
    'compare',
    'first',
    'second',
    'third',
    'tell',
    'more',
    'about',
    'recommend',
    'recommendation',
    'suggest',
    'suggestion',
    'best',
    'match',
    'option',
    'other',
    'another',
    'most',
    'selling',
    'seller',
    'bestseller',
    'new',
    'latest',
    'arrival',
    'arrivals',
    'address',
    'location',
    'contact',
    'phone',
    'whatsapp',
    'number',
    'hours',
    'opening',
    'delivery',
    'shipping',
    'what',
    'okay',
    'ok',
    'use',
    'remove',
    'without',
    'avoid',
    'false',
    'sugary',
    'for',
    'give',
    'show',
    'make',
    'me',
    'actually',
    'strictly',
    'your',
    '\u0627\u0643\u062a\u0631',
    '\u0627\u0643\u062b\u0631',
    '\u062d\u0627\u062c\u0629',
    '\u062d\u0627\u062c\u0647',
    '\u0645\u0637\u0644\u0648\u0628\u0629',
    '\u0645\u0637\u0644\u0648\u0628\u0647',
    '\u0627\u062c\u062f\u062f',
    '\u0627\u062d\u062f\u062b',
    '\u0639\u0646\u0648\u0627\u0646',
    '\u0639\u0646\u0648\u0627\u0646\u0643\u0645',
    '\u0645\u0643\u0627\u0646\u0643\u0645',
    '\u0627\u0644\u0645\u062d\u0644',
    '\u0627\u062a\u0648\u0627\u0635\u0644',
    '\u0631\u0642\u0645',
    '\u0631\u0642\u0645\u0643\u0645',
    '\u0648\u0627\u062a\u0633\u0627\u0628',
    '\u0645\u0648\u0627\u0639\u064a\u062f',
    '\u062a\u0648\u0635\u064a\u0644',
    '\u0634\u062d\u0646',
    '\u0627\u0644\u062c\u0648',
    '\u062c\u0648',
    '\u062c\u0645\u064a\u0644',
    '\u062d\u0644\u0648',
    '\u0627\u0644\u062f\u0646\u064a\u0627',
    '\u0627\u0644\u0646\u0647\u0627\u0631',
    '\u062f\u064a',
    '\u062f\u0647',
    '\u0647\u0630\u0647',
    '\u0647\u0630\u0627',
    '\u062c\u062f\u064a\u062f\u0629',
    '\u062c\u062f\u064a\u062f\u0647',
    '\u062c\u062f\u064a\u062f',
  };
  static String blankTerms(String message, Set<String> terms) {
    final chars = message.split('');
    for (final term in terms) {
      final matches = LocalIntentParser.findTermMatches(message, term);
      for (final match in matches) {
        for (var i = match.start; i < match.end; i++) {
          chars[i] = ' ';
        }
      }
    }
    return chars.join().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? extractAvailabilityProductQuery(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;
    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return null;
    }
    final isRankingRequest = LocalIntentParser.looksLikeRankingRequest(
      normalized,
    );
    if (looksLikeGenderOnlyPreferenceReply(normalized)) return null;
    if (_looksLikeContextOnlyAlternativeFollowUp(normalized)) return null;
    if (LocalIntentParser.isGreetingOnly(normalized)) return null;
    if (looksLikeRecommendationContinuationCommand(normalized)) return null;
    if (looksLikeNotePreferenceStatement(normalized)) return null;
    if (looksLikeGenericRecommendationOrPreferenceCommand(normalized)) {
      return null;
    }
    if (looksLikePersonaOrPreferenceStatement(normalized)) return null;
    if (looksLikeCatalogBrowseQuestion(normalized)) return null;
    if (_looksLikeNicheScentAvailabilityPhrase(normalized)) return null;
    if (looksLikeExplicitSimilarityRecommendationRequest(normalized)) {
      return null;
    }

    final quotedCandidate = _extractQuotedProductCandidate(normalized);
    if (quotedCandidate != null) return quotedCandidate;

    final explicitPatternCandidate = _extractFromAvailabilityPatterns(
      normalized,
    );
    if (explicitPatternCandidate != null) return explicitPatternCandidate;

    final pricePatternCandidate = _extractFromPricePatterns(normalized);
    if (pricePatternCandidate != null) return pricePatternCandidate;

    if (isRankingRequest) return null;

    var candidate = normalized.replaceAll(LocalIntentParser.punctuation, ' ');
    candidate = blankTerms(candidate, availabilityKeywords);
    candidate = blankTerms(candidate, availabilityNoisePhrases);
    candidate = blankTerms(candidate, LocalIntentParser.cheapKeywords);
    candidate = blankTerms(candidate, LocalIntentParser.strongerModifiers);
    candidate = blankTerms(candidate, LocalIntentParser.lighterModifiers);
    candidate = blankTerms(candidate, LocalIntentParser.sweeterModifiers);
    candidate = blankTerms(candidate, LocalIntentParser.revertModifiers);
    return _cleanupAvailabilityCandidate(candidate);
  }

  static String? extractRedirectedProductQuery(
    String message, {
    bool hasRecommendationContext = false,
  }) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty ||
        !hasRecommendationContext ||
        !LocalIntentParser.containsAny(
          normalized,
          recommendationRejectionKeywords,
        )) {
      return null;
    }

    final quotedCandidate = _extractQuotedProductCandidate(normalized);
    if (quotedCandidate != null) return quotedCandidate;

    final directRequestPatterns = <RegExp>[
      RegExp(r'\bi want\s+(.+?)\s+perfume\b'),
      RegExp(r'\bi want\s+(.+?)\b'),
      RegExp(r'عايز\s+(.+?)\s+عطر\b'),
      RegExp(r'عاوزه\s+(.+?)\s+عطر\b'),
      RegExp(r'عايز\s+(.+?)\b'),
      RegExp(r'عاوزه\s+(.+?)\b'),
    ];

    for (final pattern in directRequestPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match == null) continue;
      final cleaned = _cleanupAvailabilityCandidate(match.group(1) ?? '');
      if (cleaned != null) return cleaned;
    }

    return null;
  }

  static bool isGenericAvailabilityCandidate(String? candidate) {
    if (candidate == null) return true;
    final normalized = LocalIntentParser.normalizeInput(candidate);
    if (normalized.isEmpty) return true;
    if (genericAvailabilityCandidateFillers.contains(normalized)) return true;
    final tokens = normalized.split(RegExp(r'\s+'));
    return tokens.every(
      (token) =>
          availabilityStopwords.contains(token) ||
          genericSimilarityFollowUpTokens.contains(token) ||
          LocalIntentParser.cheapKeywords.contains(token) ||
          LocalIntentParser.strongerModifiers.contains(token) ||
          LocalIntentParser.lighterModifiers.contains(token),
    );
  }

  static bool looksLikeAvailabilityQuery(
    String message, {
    required bool hasRecommendationContext,
    String? extractedProduct,
  }) {
    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(message)) {
      return false;
    }
    if (LocalIntentParser.looksLikeRankingRequest(message)) {
      return false;
    }
    if (LocalIntentParser.isGreetingOnly(message)) {
      return false;
    }
    if (looksLikeRecommendationContinuationCommand(message)) {
      return false;
    }
    if (looksLikeNotePreferenceStatement(message)) {
      return false;
    }
    if (looksLikeGenericRecommendationOrPreferenceCommand(message)) {
      return false;
    }
    if (looksLikePersonaOrPreferenceStatement(message)) {
      return false;
    }
    if (looksLikeGenderOnlyPreferenceReply(message)) {
      return false;
    }
    if (looksLikeCatalogBrowseQuestion(message)) {
      return false;
    }

    if (_looksLikeNicheScentAvailabilityPhrase(message)) {
      return false;
    }
    if (looksLikeExplicitSimilarityRecommendationRequest(message)) {
      return false;
    }

    if (_extractFromAvailabilityPatterns(message) != null) {
      return true;
    }

    if (_extractFromPricePatterns(message) != null) {
      return true;
    }

    final anchoredProduct =
        extractedProduct ?? extractAvailabilityProductQuery(message);
    if (LocalIntentParser.containsAny(message, availabilityKeywords) &&
        anchoredProduct != null) {
      return true;
    }

    if (isContextualAvailabilityFollowUp(
      message,
      hasRecommendationContext: hasRecommendationContext,
    )) {
      return true;
    }

    if (_looksLikeStandalonePerfumeName(message)) {
      return true;
    }

    return extractRedirectedProductQuery(
          message,
          hasRecommendationContext: hasRecommendationContext,
        ) !=
        null;
  }

  static bool hasDirectAvailabilityCue(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (LocalIntentParser.looksLikeNoteOnlyAvailabilityPatch(normalized)) {
      return false;
    }
    if (looksLikeNotePreferenceStatement(normalized)) return false;
    if (LocalIntentParser.containsAny(normalized, availabilityKeywords)) {
      return true;
    }
    return RegExp(
      '(?:\u0645\u062a\u0648\u0641\u0631|\u0645\u062a\u0648\u0641\u0631\u0629|\u0645\u062a\u0648\u0641\u0631\u0647|\u0645\u0648\u062c\u0648\u062f|\u0645\u0648\u062c\u0648\u062f\u0629|\u0645\u0648\u062c\u0648\u062f\u0647|\u0645\u062a\u0627\u062d|\u0645\u062a\u0627\u062d\u0629|\u0645\u062a\u0627\u062d\u0647|\u0639\u0646\u062f\u0643|\u0639\u0646\u062f\u0643\u0645|مغوكر|موجوؿ|عنؿك)',
    ).hasMatch(normalized);
  }

  static String? extractQuestionShapedLatinProductQuery(String message) {
    if (!message.contains('?') && !message.contains('\u061f')) return null;
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;
    if (looksLikeGenericRecommendationOrPreferenceCommand(normalized)) {
      return null;
    }

    final latinChunks = RegExp(
      r"[A-Za-z][A-Za-z0-9 .'-]*",
    ).allMatches(message).map((match) => match.group(0) ?? '').toList();
    if (latinChunks.isEmpty) return null;

    const stopwords = {
      'do',
      'you',
      'have',
      'is',
      'there',
      'any',
      'it',
      'the',
      'available',
      'stock',
      'price',
      'cost',
      'card',
      'perfume',
      'fragrance',
    };
    final tokens = latinChunks
        .join(' ')
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .where((token) => !stopwords.contains(token.toLowerCase()))
        .toList(growable: false);
    if (tokens.length < 2 || tokens.length > 6) return null;
    final candidate = tokens.join(' ').trim();
    if (!RegExp(r'[A-Za-z]').hasMatch(candidate)) return null;
    return candidate;
  }

  static bool looksLikeLatinStandaloneName(String message) {
    final cleaned = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (LocalIntentParser.isGreetingOnly(cleaned)) return false;
    if (looksLikeRecommendationContinuationCommand(cleaned)) return false;
    if (looksLikeGenericRecommendationOrPreferenceCommand(cleaned)) {
      return false;
    }
    if (looksLikePersonaOrPreferenceStatement(cleaned)) return false;
    if (cleaned.length < 5 || cleaned.length > 70) return false;
    if (!RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .'-]*$").hasMatch(cleaned)) {
      return false;
    }
    final tokens = cleaned
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2 || tokens.length > 6) return false;
    if (tokens.any(_standalonePerfumeNameBlockedTokens.contains)) return false;

    return tokens.any((token) => token.length > 2);
  }

  static bool looksLikeRecommendationContinuationCommand(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    final hasExplicitAvailabilityKeyword = LocalIntentParser.containsAny(
      normalized,
      availabilityKeywords,
    );
    if (hasExplicitAvailabilityKeyword) return false;

    return normalized.contains('recommend best match') ||
        normalized.contains('recommend the best match') ||
        normalized.contains('best match for me') ||
        normalized.contains('best option') ||
        normalized.contains('best recommendation') ||
        normalized.contains('show me the best') ||
        normalized.contains('give me your best') ||
        normalized.contains('give me best') ||
        normalized.contains('give me the best') ||
        normalized.contains('recommend one') ||
        normalized.contains('افضل اختيار') ||
        normalized.contains('أفضل اختيار') ||
        normalized.contains('رشحلي افضل') ||
        normalized.contains('رشحلي أفضل') ||
        normalized.contains('رشح افضل') ||
        normalized.contains('رشح أفضل') ||
        normalized.contains('اقترح افضل') ||
        normalized.contains('اقترح أفضل') ||
        normalized.contains('اختارلي افضل') ||
        normalized.contains('اختارلي أفضل') ||
        normalized.contains('افضل اختيار') ||
        normalized.contains('أفضل اختيار') ||
        normalized.contains('اقترح افضل') ||
        normalized.contains('اقترح أفضل') ||
        normalized.contains('make it under') ||
        normalized.contains('make it strictly under') ||
        normalized.contains('actually make it') ||
        normalized.contains('actually make strictly') ||
        normalized.contains('actually make it strictly');
  }

  static bool looksLikeGenericRecommendationOrPreferenceCommand(
    String message,
  ) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (LocalIntentParser.containsAny(normalized, availabilityKeywords)) {
      return false;
    }
    if (_looksLikeKnownStandaloneProductShape(normalized)) return false;

    final hasRecommendationCommand =
        RegExp(
          r'\b(suggest|recommend|show|give me|find|pick|choose)\b',
        ).hasMatch(normalized) &&
        (normalized.contains('perfume') ||
            normalized.contains('fragrance') ||
            normalized.contains('any other') ||
            normalized.contains('other') ||
            normalized.contains('option') ||
            normalized.contains('most selling') ||
            normalized.contains('best seller') ||
            normalized.contains('bestseller') ||
            normalized.contains('best perfume') ||
            normalized.contains('best fragrance') ||
            normalized.contains('best match') ||
            normalized.contains('new'));
    final hasBrowseCommand =
        normalized.contains('what is new') ||
        normalized.contains("what's new") ||
        normalized.contains('whats new') ||
        normalized.contains('what new') ||
        normalized.contains('new arrivals') ||
        normalized.contains('latest') ||
        normalized.contains('new perfumes') ||
        normalized.contains('new fragrances') ||
        normalized.contains('most selling') ||
        normalized.contains('best seller') ||
        normalized.contains('bestseller') ||
        normalized.contains('best perfume') ||
        normalized.contains('best fragrance') ||
        normalized.contains('top perfume') ||
        normalized.contains('أكتر حاجة مطلوبة') ||
        normalized.contains('أكتر حاجه مطلوبه') ||
        normalized.contains('اكتر حاجة مطلوبة') ||
        normalized.contains('اكتر حاجه مطلوبه') ||
        normalized.contains('اكثر حاجة مطلوبة') ||
        normalized.contains('اكثر حاجه مطلوبه') ||
        normalized.contains('الاكثر طلب') ||
        normalized.contains('الأكثر طلب') ||
        normalized.contains('اجدد العطور') ||
        normalized.contains('أجدد العطور') ||
        normalized.contains('احدث العطور') ||
        normalized.contains('أحدث العطور') ||
        normalized.contains('احسن عطر') ||
        normalized.contains('افضل عطر') ||
        normalized.contains('أفضل عطر');
    final hasBusinessInfoCommand =
        _containsEnglishWord(normalized, 'address') ||
        _containsEnglishWord(normalized, 'location') ||
        _containsEnglishWord(normalized, 'contact') ||
        _containsEnglishWord(normalized, 'phone') ||
        _containsEnglishWord(normalized, 'whatsapp') ||
        normalized.contains('opening hours') ||
        normalized.contains('working hours') ||
        _containsEnglishWord(normalized, 'delivery') ||
        _containsEnglishWord(normalized, 'shipping') ||
        normalized.contains('العنوان') ||
        normalized.contains('عنوانكم') ||
        normalized.contains('مكانكم') ||
        normalized.contains('فين المحل') ||
        normalized.contains('المحل فين') ||
        normalized.contains('اتواصل') ||
        normalized.contains('رقمكم') ||
        normalized.contains('واتساب') ||
        normalized.contains('مواعيد') ||
        normalized.contains('توصيل') ||
        normalized.contains('شحن');
    final hasPreferencePatchCommand =
        RegExp(r'\b(remove|without|avoid)\b').hasMatch(normalized) ||
        RegExp(r'\b\w+\s*=\s*false\b').hasMatch(normalized) ||
        normalized.contains('not sugary') ||
        normalized.contains('sugary false') ||
        normalized.contains('sugary=false');
    final hasContextFollowUp =
        normalized == 'daily use' ||
        normalized == 'for daily use' ||
        normalized == 'okay university' ||
        normalized == 'ok university' ||
        normalized == 'university' ||
        normalized.contains('for daily use') ||
        normalized.contains('daily use') ||
        normalized.contains('okay university');

    return hasRecommendationCommand ||
        hasBrowseCommand ||
        hasBusinessInfoCommand ||
        hasPreferencePatchCommand ||
        hasContextFollowUp;
  }

  static bool looksLikeNotePreferenceStatement(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;

    const noteTerms = {
      'oud',
      'agarwood',
      'vanilla',
      'musk',
      'rose',
      'sandalwood',
      'woody',
      '\u0639\u0648\u062f',
      '\u0641\u0627\u0646\u064a\u0644\u064a\u0627',
      '\u0645\u0633\u0643',
      '\u0648\u0631\u062f',
      '\u0635\u0646\u062f\u0644',
      '\u062e\u0634\u0628\u064a',
      '\u062e\u0634\u0628',
    };
    final mentionsNote = noteTerms.any(normalized.contains);
    if (!mentionsNote) return false;

    final hasEnglishPreferenceCue = RegExp(
      r'\b(avoid|remove|without|no|keep|make it|make this|with)\b',
    ).hasMatch(normalized);
    final hasArabicPreferenceCue =
        normalized.contains('\u0628\u0644\u0627\u0634') ||
        normalized.contains('\u0645\u0646 \u063a\u064a\u0631') ||
        normalized.contains('\u0634\u064a\u0644') ||
        normalized.contains('\u062e\u0644\u064a\u0647') ||
        normalized.contains('\u062e\u0644\u064a\u0647\u0627') ||
        normalized.contains('\u0641\u064a\u0647') ||
        normalized.contains('\u0641\u064a\u0647\u0627') ||
        normalized.contains('\u0639\u0627\u064a\u0632') ||
        normalized.contains('\u0639\u0627\u0648\u0632');
    return hasEnglishPreferenceCue || hasArabicPreferenceCue;
  }

  static bool looksLikeCatalogBrowseQuestion(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (looksLikeGenericRecommendationOrPreferenceCommand(normalized)) {
      return false;
    }
    if (looksLikePersonaOrPreferenceStatement(normalized)) {
      return false;
    }

    const browsePhrases = [
      'what types do you have',
      'what type do you have',
      'what kinds do you have',
      'what kind do you have',
      'what categories do you have',
      'what category do you have',
      'what options do you have',
      'what brands do you have',
      'what perfumes do you have',
      'what fragrances do you have',
      'types do you have',
      'kinds do you have',
      'categories do you have',
      'available types',
      'available categories',
      '\u0627\u064a\u0647 \u0627\u0644\u0627\u0646\u0648\u0627\u0639 \u0627\u0644\u0644\u064a \u0639\u0646\u062f\u0643\u0645',
      '\u0627\u0644\u0627\u0646\u0648\u0627\u0639 \u0627\u0644\u0645\u062a\u0627\u062d\u0629',
      '\u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a \u0627\u0644\u0645\u062a\u0627\u062d\u0629',
      '\u0627\u064a\u0647 \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a',
    ];
    return browsePhrases.any(normalized.contains);
  }

  static bool looksLikeGenderOnlyPreferenceReply(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;

    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    const genderOnlyReplies = {
      'men',
      'women',
      'male',
      'female',
      'man',
      'woman',
      'unisex',
      '\u0631\u062c\u0627\u0644\u064a',
      '\u0631\u062c\u0627\u0644\u064a\u0629',
      '\u0631\u062c\u0627\u0644',
      '\u062d\u0631\u064a\u0645\u064a',
      '\u0646\u0633\u0627\u0626\u064a',
      '\u0646\u0633\u0627\u0621',
      '\u0644\u0644\u0627\u062b\u0646\u064a\u0646',
      '\u0627\u0644\u062b\u0646\u064a\u0646',
      '\u064a\u0648\u0646\u064a\u0633\u064a\u0643\u0633',
    };
    if (genderOnlyReplies.contains(compact)) {
      return true;
    }

    final tokens = compact
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.length != 1) return false;
    return genderOnlyReplies.contains(tokens.first);
  }

  static bool _looksLikeContextOnlyAlternativeFollowUp(String normalized) {
    final hasArabicSimilarity =
        normalized.contains('شبه') ||
        normalized.contains('زيه') ||
        normalized.contains('قريب منه') ||
        normalized.contains('مشابه') ||
        normalized.contains('بديل');
    final hasArabicGenericRequest =
        normalized.contains('رشح') ||
        normalized.contains('حاجة') ||
        normalized.contains('حاجه') ||
        normalized.contains('طيب') ||
        normalized.contains('طب');
    final hasEnglishContextualSimilarity =
        normalized.contains('like it') ||
        normalized.contains('something like it') ||
        normalized.contains('similar') ||
        normalized.contains('alternative');
    final hasEnglishCheaperCue =
        normalized.contains('cheaper') ||
        normalized.contains('lower price') ||
        normalized.contains('less expensive') ||
        normalized.contains('more affordable');
    return (hasArabicSimilarity && hasArabicGenericRequest) ||
        (hasEnglishContextualSimilarity && hasEnglishCheaperCue) ||
        normalized.contains('closest thing you have') ||
        normalized.contains('closest thing') ||
        normalized.contains('something like it') ||
        normalized.contains('if not') ||
        normalized.contains('closest alternative') ||
        normalized.contains('recommend the closest') ||
        normalized.contains('recommend closest');
  }

  static bool looksLikeClosestAvailabilityAlternativeRequest(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    return _looksLikeContextOnlyAlternativeFollowUp(normalized) ||
        normalized.contains('closest available') ||
        normalized.contains('closest option') ||
        normalized.contains('closest thing you have');
  }

  static bool looksLikeExplicitSimilarityRecommendationRequest(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;

    final hasSimilarityCue =
        normalized.contains('something like') ||
        normalized.contains('something similar') ||
        normalized.contains('similar to') ||
        normalized.contains('same smell') ||
        normalized.contains('same vibe') ||
        normalized.contains('smells like') ||
        normalized.contains('scent like') ||
        normalized.contains('alternative to') ||
        normalized.contains('closest to');
    if (!hasSimilarityCue) return false;

    return normalized.contains('perfume') ||
        normalized.contains('fragrance') ||
        normalized.contains('cheaper') ||
        normalized.contains('lower price') ||
        normalized.contains('less expensive') ||
        normalized.contains('more affordable') ||
        normalized.contains('do you have') ||
        normalized.contains('recommend') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0628\u0631\u0641\u0627\u0646');
  }

  static bool looksLikePersonaOrPreferenceStatement(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return false;
    if (LocalIntentParser.containsAny(normalized, availabilityKeywords)) {
      return false;
    }
    if (_looksLikeKnownStandaloneProductShape(normalized)) return false;

    final hasFirstPersonAnchor = RegExp(
      r"\b(i|im|i'm|i am|my|me)\b",
    ).hasMatch(normalized);
    if (!hasFirstPersonAnchor) return false;

    final hasAgeSignal =
        RegExp(
          r'\b\d{1,2}\s*(?:year old|years old|yr old|yrs old)\b',
        ).hasMatch(normalized) ||
        RegExp(r'\b\d{1,2}\s*-\s*year\s*-\s*old\b').hasMatch(normalized);
    final hasWorkSignal =
        RegExp(
          r'\b(i work|work in|working in|my work|my job)\b',
        ).hasMatch(normalized) ||
        LocalIntentParser.containsAny(normalized, const {
          'finance',
          'banking',
          'corporate',
          'professional',
        });
    final hasBudgetSignal =
        RegExp(r'\bmy budget\b').hasMatch(normalized) ||
        RegExp(r'\bi have\s+\d+(?:\s*egp)?\b').hasMatch(normalized) ||
        RegExp(r'\bwith\s+\d+\s*egp\b').hasMatch(normalized);
    final hasPreferenceSignal =
        RegExp(
          r'\b(i prefer|prefer|i like|like|i want|want|i need|need)\b',
        ).hasMatch(normalized) &&
        !LocalIntentParser.containsAny(
          normalized,
          recommendationRejectionKeywords,
        );
    final hasExplicitGenderPersona = RegExp(
      r"\b(i am|im|i'm)\s+(?:a\s+)?(?:man|male|woman|female)\b",
    ).hasMatch(normalized);

    return hasAgeSignal ||
        hasWorkSignal ||
        hasBudgetSignal ||
        hasPreferenceSignal ||
        hasExplicitGenderPersona;
  }

  static bool _looksLikeKnownStandaloneProductShape(String normalized) {
    const knownStandaloneNames = {
      'dior sauvage',
      'sauvage parfum',
      'bleu de chanel',
    };
    return knownStandaloneNames.contains(normalized);
  }

  static bool _looksLikeStandalonePerfumeName(String message) {
    final cleaned = message
        .replaceAll(LocalIntentParser.punctuation, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.length > 70) return false;
    if (LocalIntentParser.isGreetingOnly(cleaned)) return false;
    if (LocalIntentParser.containsAny(cleaned, availabilityKeywords)) {
      return false;
    }
    if (looksLikeGenericRecommendationOrPreferenceCommand(cleaned)) {
      return false;
    }
    if (looksLikeRecommendationContinuationCommand(cleaned)) return false;
    if (looksLikePersonaOrPreferenceStatement(cleaned)) return false;
    final candidate = _cleanupAvailabilityCandidate(
      cleaned,
      trimStopwordEdges: false,
    );
    if (candidate == null || candidate != cleaned) return false;
    final tokens = candidate.split(RegExp(r'\s+'));
    if (tokens.length < 2 || tokens.length > 6) return false;
    if (tokens.any(_standalonePerfumeNameBlockedTokens.contains)) return false;
    if (tokens.any((token) => RegExp(r'\d').hasMatch(token))) return true;
    return tokens.every(
      (token) =>
          !availabilityStopwords.contains(token) &&
          !genericSimilarityFollowUpTokens.contains(token),
    );
  }

  static bool _looksLikeNicheScentAvailabilityPhrase(String message) {
    final normalized = LocalIntentParser.normalizeInput(message);
    final hasNicheScent = _nicheScentAvailabilityTerms.any(
      (term) => normalized.contains(LocalIntentParser.normalizeInput(term)),
    );
    if (!hasNicheScent) return false;

    return LocalIntentParser.containsAny(normalized, availabilityKeywords) ||
        normalized.contains('something like') ||
        normalized.contains('smells like') ||
        normalized.contains('scent like');
  }

  static bool isContextualAvailabilityFollowUp(
    String message, {
    required bool hasRecommendationContext,
  }) {
    if (!hasRecommendationContext) return false;
    final cleaned = message
        .replaceAll(LocalIntentParser.punctuation, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.length > 20) return false;
    return contextualAvailabilityFollowUpPhrases.contains(cleaned);
  }

  static String? _extractQuotedProductCandidate(String message) {
    final quotedPatterns = <RegExp>[
      RegExp(r'"([^"]{2,80})"'),
      RegExp(r"'([^']{2,80})'"),
      RegExp(r'“([^”]{2,80})”'),
      RegExp(r'«([^»]{2,80})»'),
    ];

    for (final pattern in quotedPatterns) {
      final match = pattern.firstMatch(message);
      if (match == null) continue;
      final cleaned = _cleanupAvailabilityCandidate(
        match.group(1) ?? '',
        trimStopwordEdges: false,
      );
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static String? _extractFromAvailabilityPatterns(String message) {
    final sanitizedMessage = message.replaceAll(RegExp(r'[?؟؟]+$'), '').trim();
    final patterns = <RegExp>[
      RegExp(r'\bdo you have\s+(.+?)(?:\s+in stock)?$'),
      RegExp(r'\bis\s+(.+?)\s+available$'),
      RegExp(r'\bis there\s+(.+?)$'),
      RegExp(
        'هل\\s+عطر\\s+(.+?)\\s+(?:موجود|موجودة|موجوده|متوفر|متوفرة|متوفره|متاح|متاحة|متاحه)\$',
      ),
      RegExp('هل\\s+عندك(?:م)?\\s+(.+?)\$'),
      RegExp(
        '(?:متوفر|متوفرة|متوفره|موجود|موجودة|موجوده|متاح|متاحة|متاحه)\\s+عندك(?:م)?\\s+(.+?)\$',
      ),
      RegExp(
        '(.+?)\\s+(?:موجود|موجودة|موجوده|متوفر|متوفرة|متوفره|متاح|متاحة|متاحه)\$',
      ),
      RegExp(r'مغوكر\s+عنؿك\s+(.+?)$'),
      RegExp(r'هل\s+عنؿك\s+(.+?)$'),
      RegExp(r'\bهل\s+(.+?)\s+(?:موجود|موجوده|متوفر|متوفره|متاح|متاحه)$'),
      RegExp(r'\b(.+?)\s+(?:موجود|موجوده|متوفر|متوفره|متاح|متاحه)$'),
      RegExp(r'\b(?:عندكم|عندك)\s+(.+?)$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(sanitizedMessage);
      if (match == null) continue;
      final cleaned = _cleanupAvailabilityCandidate(
        match.group(1) ?? '',
        trimStopwordEdges: false,
      );
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static String? _extractFromPricePatterns(String message) {
    final sanitizedMessage = message
        .replaceAll(RegExp(r'[?\u061F]+$'), '')
        .trim();
    final patterns = <RegExp>[
      RegExp(r'\b(?:price|cost)\s+(?:of\s+)?(.+?)$'),
      RegExp(r'\bhow much\s+(?:is\s+)?(.+?)$'),
      RegExp(r'\b(.+?)\s+(?:price|cost)$'),
      RegExp(
        r'(?:\u0643\u0645\s+\u0633\u0639\u0631|\u0633\u0639\u0631)\s+(.+?)$',
      ),
      RegExp(
        r'(.+?)\s+(?:\u0628\u0643\u0627\u0645|\u0628\u0643\u0645|\u0643\u0627\u0645)$',
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(sanitizedMessage);
      if (match == null) continue;
      final cleaned = _cleanupAvailabilityCandidate(
        match.group(1) ?? '',
        trimStopwordEdges: true,
      );
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static String? _cleanupAvailabilityCandidate(
    String raw, {
    bool trimStopwordEdges = true,
  }) {
    final boundedRaw = _trimAfterIntentBoundary(raw);
    final tokens = boundedRaw
        .replaceAll(LocalIntentParser.punctuation, ' ')
        .replaceAll(RegExp(r'[?؟؟]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .where((token) => token.length >= 2)
        .toList();

    if (tokens.isEmpty) return null;

    if (trimStopwordEdges) {
      while (tokens.isNotEmpty &&
          availabilityStopwords.contains(tokens.first)) {
        tokens.removeAt(0);
      }
      while (tokens.isNotEmpty && availabilityStopwords.contains(tokens.last)) {
        tokens.removeLast();
      }
    }

    final normalizedTokens = tokens
        .map(LocalIntentParser.normalizeInput)
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (normalizedTokens.isEmpty) return null;

    final meaningfulTokens = normalizedTokens
        .where((token) => !_isGenericSimilarityOrFollowUpToken(token))
        .toList(growable: false);
    if (meaningfulTokens.isEmpty) return null;

    final query = meaningfulTokens.join(' ').trim();
    if (query.length < 3) return null;
    if (genericAvailabilityCandidateFillers.contains(query)) return null;
    return query;
  }

  static String _trimAfterIntentBoundary(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final padded = ' $trimmed ';
    final boundaries = <String>[
      ' if not ',
      ' if available ',
      ' and compare ',
      ' compare ',
      ' and recommend ',
      ' then recommend ',
      ' recommend ',
      ' \u0648\u0644\u0648 ',
      ' \u0644\u0648 ',
      ' \u0642\u0627\u0631\u0646 ',
      ' \u0648\u0642\u0627\u0631\u0646 ',
      ' \u0631\u0634\u062d ',
      ' \u0648\u0631\u0634\u062d ',
    ];
    var bestIndex = -1;
    for (final boundary in boundaries) {
      final index = padded.indexOf(boundary);
      if (index > 0 && (bestIndex == -1 || index < bestIndex)) {
        bestIndex = index;
      }
    }
    if (bestIndex == -1) return trimmed;
    return padded.substring(1, bestIndex).trim();
  }

  static bool _isGenericSimilarityOrFollowUpToken(String token) {
    return availabilityStopwords.contains(token) ||
        genericSimilarityFollowUpTokens.contains(token);
  }

  static bool _containsEnglishWord(String message, String word) {
    return RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    ).hasMatch(message);
  }
}
