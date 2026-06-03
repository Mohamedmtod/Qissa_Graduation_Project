import 'package:perfume_app/features/ai_chat/data/models/availability_context.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_reference_profile_registry.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_matchers.dart'
    as parser_matchers;
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum AvailabilityMatchType { exact, phrase, partial, ambiguous, none }

enum AvailabilityStockState { inStock, outOfStock, unknown }

class AvailabilityLookupResult {
  final ProductModel? product;
  final List<ProductModel> options;
  final AvailabilityMatchType matchType;
  final AvailabilityStockState stockState;

  const AvailabilityLookupResult._({
    this.product,
    this.options = const [],
    this.matchType = AvailabilityMatchType.none,
    this.stockState = AvailabilityStockState.unknown,
  });

  const AvailabilityLookupResult.found({
    required ProductModel product,
    required AvailabilityMatchType matchType,
    required AvailabilityStockState stockState,
  }) : this._(product: product, matchType: matchType, stockState: stockState);

  const AvailabilityLookupResult.notFound()
    : this._(matchType: AvailabilityMatchType.none);

  const AvailabilityLookupResult.ambiguous({
    required List<ProductModel> options,
  }) : this._(options: options, matchType: AvailabilityMatchType.ambiguous);

  bool get isAmbiguous => matchType == AvailabilityMatchType.ambiguous;
}

class AvailabilityMatchCandidate {
  final ProductModel product;
  final AvailabilityMatchType matchType;
  final int score;
  final int queryTokens;

  const AvailabilityMatchCandidate({
    required this.product,
    required this.matchType,
    required this.score,
    required this.queryTokens,
  });

  bool get isMatch => matchType != AvailabilityMatchType.none;

  factory AvailabilityMatchCandidate.fromProduct({
    required ProductModel product,
    required String query,
    required List<String> queryTokens,
  }) {
    final terms = CatalogProductMatcher.termsFor(product);
    final normalizedName = CatalogProductMatcher.normalize(product.name);
    final haystack = terms.join(' ').trim();
    final haystackTokens = _availabilityLookupTokens(haystack).toSet();
    if (haystack.isEmpty) {
      return AvailabilityMatchCandidate(
        product: product,
        matchType: AvailabilityMatchType.none,
        score: 0,
        queryTokens: queryTokens.length,
      );
    }

    if (terms.any((term) => query == term)) {
      return AvailabilityMatchCandidate(
        product: product,
        matchType: AvailabilityMatchType.exact,
        score: 400,
        queryTokens: queryTokens.length,
      );
    }

    String? phraseTerm;
    for (final term in terms) {
      if (CatalogProductMatcher.containsTerm(query, term) ||
          (term.contains(' ') &&
              CatalogProductMatcher.containsTerm(term, query))) {
        phraseTerm = term;
        break;
      }
    }
    if (haystack == query || phraseTerm != null) {
      return AvailabilityMatchCandidate(
        product: product,
        matchType: AvailabilityMatchType.phrase,
        score: 260 + queryTokens.length * 10 + (phraseTerm?.length ?? 0),
        queryTokens: queryTokens.length,
      );
    }

    var matchedTokens = 0;
    var fuzzyMatchedTokens = 0;
    var tokenScore = 0;
    for (final token in queryTokens) {
      if (haystackTokens.contains(token)) {
        matchedTokens += 1;
        tokenScore += 18;
        if (normalizedName.startsWith(token)) {
          tokenScore += 4;
        }
        continue;
      }
      if (_hasFuzzyAvailabilityToken(haystackTokens, token)) {
        matchedTokens += 1;
        fuzzyMatchedTokens += 1;
        tokenScore += 12;
      }
    }

    if (fuzzyMatchedTokens > 0) {
      return AvailabilityMatchCandidate(
        product: product,
        matchType: AvailabilityMatchType.none,
        score: 0,
        queryTokens: queryTokens.length,
      );
    }

    if (matchedTokens == 0 || (queryTokens.length > 1 && matchedTokens < 2)) {
      return AvailabilityMatchCandidate(
        product: product,
        matchType: AvailabilityMatchType.none,
        score: 0,
        queryTokens: queryTokens.length,
      );
    }

    if (matchedTokens == queryTokens.length && queryTokens.length > 1) {
      tokenScore += 18;
    }

    return AvailabilityMatchCandidate(
      product: product,
      matchType: AvailabilityMatchType.partial,
      score: tokenScore,
      queryTokens: queryTokens.length,
    );
  }
}

bool _hasFuzzyAvailabilityToken(Set<String> haystackTokens, String queryToken) {
  if (queryToken.length < 5) return false;
  for (final token in haystackTokens) {
    final maxDistance = token.length >= 7 ? 2 : 1;
    if (parser_matchers.arabicChar(queryToken) !=
        parser_matchers.arabicChar(token)) {
      continue;
    }
    if ((queryToken.length - token.length).abs() > maxDistance) continue;
    if (!parser_matchers.arabicChar(token) && queryToken[0] != token[0]) {
      continue;
    }
    if (parser_matchers.isWithinEditDistance(queryToken, token, maxDistance)) {
      return true;
    }
  }
  return false;
}

const Set<String> _availabilityLookupStopwords = {
  'a',
  'an',
  'and',
  'available',
  'availble',
  'avialable',
  'de',
  'des',
  'du',
  'eau',
  'for',
  'fragrance',
  'in',
  'is',
  'it',
  'la',
  'le',
  'les',
  'of',
  'parfum',
  'perfume',
  'pour',
  'stock',
  'price',
  'cost',
  'that',
  'the',
  'this',
  '\u0639\u0637\u0631',
  '\u0628\u0631\u0641\u0627\u0646',
  '\u0627\u0644\u0639\u0637\u0631',
  '\u0627\u0644\u0628\u0631\u0641\u0627\u0646',
  '\u0633\u0639\u0631',
  '\u0627\u0644\u0633\u0639\u0631',
  '\u0628\u0643\u0627\u0645',
  '\u0628\u0643\u0645',
  '\u0643\u0627\u0645',
  '\u0643\u0645',
  '\u0645\u0648\u062c\u0648\u062f',
  '\u0645\u0648\u062c\u0648\u062f\u0647',
  '\u0645\u062a\u0648\u0641\u0631',
  '\u0645\u062a\u0648\u0641\u0631\u0647',
  '\u0645\u062a\u0627\u062d',
  '\u0645\u062a\u0627\u062d\u0647',
  '\u0639\u0646\u062f\u0643',
  '\u0639\u0646\u062f\u0643\u0645',
};

String _normalizeAvailabilityText(String text) {
  return CatalogProductMatcher.normalize(text);
}

List<String> _availabilityLookupTokens(String text) {
  return text
      .split(RegExp(r'\s+'))
      .map(CatalogProductMatcher.stripArabicArticleFromToken)
      .where((token) => token.length >= 2)
      .where((token) => !_availabilityLookupStopwords.contains(token))
      .toSet()
      .toList(growable: false);
}

AvailabilityLookupResult lookupAvailability(
  String query,
  List<ProductModel> catalog,
) {
  final normalizedQuery = _normalizeAvailabilityText(query);
  if (normalizedQuery.isEmpty) {
    return const AvailabilityLookupResult.notFound();
  }

  final queryTokens = _availabilityLookupTokens(normalizedQuery);
  if (queryTokens.isEmpty) {
    return const AvailabilityLookupResult.notFound();
  }

  final List<AvailabilityMatchCandidate> normalizedCatalog = catalog
      .map(
        (product) => AvailabilityMatchCandidate.fromProduct(
          product: product,
          query: normalizedQuery,
          queryTokens: queryTokens,
        ),
      )
      .where((candidate) => candidate.isMatch)
      .toList();

  if (normalizedCatalog.isEmpty) {
    return const AvailabilityLookupResult.notFound();
  }

  normalizedCatalog.sort((a, b) {
    final tier = a.matchType.index.compareTo(b.matchType.index);
    if (tier != 0) return tier;
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    return a.product.name.length.compareTo(b.product.name.length);
  });

  final best = normalizedCatalog.first;
  final runnerUp = normalizedCatalog.length > 1 ? normalizedCatalog[1] : null;

  final isAmbiguous =
      runnerUp != null && needsAvailabilityClarification(best, runnerUp);
  if (isAmbiguous) {
    return AvailabilityLookupResult.ambiguous(
      options: [best.product, runnerUp.product],
    );
  }

  final stockState = best.product.stock > 0
      ? AvailabilityStockState.inStock
      : AvailabilityStockState.outOfStock;

  return AvailabilityLookupResult.found(
    product: best.product,
    matchType: best.matchType,
    stockState: stockState,
  );
}

bool needsAvailabilityClarification(
  AvailabilityMatchCandidate best,
  AvailabilityMatchCandidate runnerUp,
) {
  if (best.matchType == AvailabilityMatchType.exact) {
    return runnerUp.matchType == AvailabilityMatchType.exact &&
        best.score == runnerUp.score;
  }

  if (best.queryTokens <= 1) {
    return runnerUp.score > 0;
  }

  if (best.matchType == AvailabilityMatchType.phrase) {
    return runnerUp.matchType != AvailabilityMatchType.exact &&
        (best.score - runnerUp.score).abs() <= 12;
  }

  final scoreGap = best.score - runnerUp.score;
  return scoreGap <= 8;
}

AvailabilityContext? resolveAvailabilityContextForFollowUp({
  required String message,
  required List<ProductModel> catalog,
  required AvailabilityContext currentAvailabilityContext,
  required RecommendationMemory recommendationMemory,
  required SessionPreferences Function(ProductModel product)
  availabilityHintsFromProduct,
  required SessionPreferences Function(AvailabilityReferenceProfile profile)
  availabilityHintsFromProfile,
}) {
  final explicitContext = resolveExplicitAvailabilityContextFromMessage(
    message: message,
    catalog: catalog,
    availabilityHintsFromProduct: availabilityHintsFromProduct,
    availabilityHintsFromProfile: availabilityHintsFromProfile,
  );
  final currentProductId = currentAvailabilityContext.matchedProductId;
  final explicitProductId = explicitContext?.matchedProductId;
  final shouldSwitchToExplicit =
      explicitContext != null &&
      _hasAvailabilityProductSwitchIntent(message) &&
      (currentProductId == null ||
          explicitProductId == null ||
          explicitProductId != currentProductId);

  if (shouldSwitchToExplicit) {
    return explicitContext;
  }

  if (currentAvailabilityContext.hasContext) {
    return currentAvailabilityContext;
  }

  final focusedProductId = recommendationMemory.lastFocusedProductId;
  if (focusedProductId != null) {
    for (final product in catalog) {
      if (product.id == focusedProductId) {
        return AvailabilityContext(
          lastQuery: product.name,
          matchedProductId: product.id,
          matchedProductName: product.name,
          availabilityStatus: product.stock > 0
              ? AvailabilityStatus.found
              : AvailabilityStatus.outOfStock,
          hints: availabilityHintsFromProduct(product),
          source: 'catalog_match',
        );
      }
    }
  }

  if (explicitContext != null) {
    return explicitContext;
  }

  return null;
}

bool _hasAvailabilityProductSwitchIntent(String message) {
  final normalized = _normalizeAvailabilityText(message);
  if (normalized.isEmpty) return false;

  const switchSignals = <String>[
    'طب',
    'طيب',
    'بدل',
    'غير',
    'قصدي',
    'قصدك',
    'مش ده',
    'مش دا',
    'بالنسبة',
    'بالنسبه',
    'وبالنسبة',
    'وبالنسبه',
    'اما',
    'بالنسبه ل',
    'بالنسبة ل',
    'what about',
    'instead',
    'switch',
    'change',
    'different',
    'not that',
  ];

  return switchSignals.any(
    (signal) => _containsSwitchSignal(normalized, signal),
  );
}

bool _containsSwitchSignal(String normalizedMessage, String signal) {
  final normalizedSignal = _normalizeAvailabilityText(signal);
  if (normalizedSignal.isEmpty) return false;

  final paddedMessage = ' $normalizedMessage ';
  final paddedSignal = ' $normalizedSignal ';
  return paddedMessage.contains(paddedSignal);
}

AvailabilityContext? resolveExplicitAvailabilityContextFromMessage({
  required String message,
  required List<ProductModel> catalog,
  required SessionPreferences Function(ProductModel product)
  availabilityHintsFromProduct,
  required SessionPreferences Function(AvailabilityReferenceProfile profile)
  availabilityHintsFromProfile,
}) {
  final normalizedMessage = _normalizeAvailabilityText(message);
  if (normalizedMessage.isEmpty) return null;

  ProductModel? bestMatched;
  var bestLength = 0;
  for (final product in catalog) {
    String? matchedTerm;
    for (final term in CatalogProductMatcher.termsFor(product)) {
      if (CatalogProductMatcher.containsTerm(normalizedMessage, term)) {
        matchedTerm = term;
        break;
      }
    }
    if (matchedTerm == null || matchedTerm.isEmpty) continue;
    if (matchedTerm.length > bestLength) {
      bestMatched = product;
      bestLength = matchedTerm.length;
    }
  }

  if (bestMatched != null) {
    final matched = bestMatched;
    return AvailabilityContext(
      lastQuery: matched.name,
      matchedProductId: matched.id,
      matchedProductName: matched.name,
      availabilityStatus: matched.stock > 0
          ? AvailabilityStatus.found
          : AvailabilityStatus.outOfStock,
      hints: availabilityHintsFromProduct(matched),
      source: 'catalog_match',
    );
  }

  final explicitQuery = AvailabilityIntentUtils.extractAvailabilityProductQuery(
    message,
  );
  if (explicitQuery != null) {
    final lookup = lookupAvailability(explicitQuery, catalog);
    if (lookup.product != null) {
      final product = lookup.product!;
      return AvailabilityContext(
        lastQuery: explicitQuery,
        matchedProductId: product.id,
        matchedProductName: product.name,
        availabilityStatus:
            lookup.stockState == AvailabilityStockState.outOfStock
            ? AvailabilityStatus.outOfStock
            : AvailabilityStatus.found,
        hints: availabilityHintsFromProduct(product),
        source: 'catalog_match',
      );
    }
  }

  final profile = AvailabilityReferenceProfileRegistry.resolveByMessage(
    message,
  );
  if (profile != null) {
    return AvailabilityContext(
      lastQuery: message.trim(),
      availabilityStatus: AvailabilityStatus.notFoundKnownProfile,
      referenceProfileKey: profile.key,
      hints: availabilityHintsFromProfile(profile),
      source: 'reference_profile',
    );
  }

  return null;
}
