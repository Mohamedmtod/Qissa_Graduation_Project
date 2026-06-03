import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_product_matcher.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser_matchers.dart'
    as parser_matchers;
import 'package:perfume_app/features/products/data/models/product_model.dart';

class MentionedProductResolver {
  static List<ProductModel> resolveMany({
    required String message,
    required List<ProductModel> catalog,
    int limit = 4,
  }) {
    final normalized = CatalogProductMatcher.normalize(message);
    if (normalized.isEmpty) return const [];

    final candidates = <_MentionedProductCandidate>[];
    for (final product in catalog) {
      final score = _scoreProductMention(normalized, product);
      if (score <= 0) continue;
      candidates.add(_MentionedProductCandidate(product, score));
    }

    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.product.name.length.compareTo(b.product.name.length);
    });

    final resolved = <ProductModel>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      if (!seen.add(candidate.product.id)) continue;
      resolved.add(candidate.product);
      if (resolved.length >= limit) break;
    }
    return resolved;
  }

  static ProductModel? resolveBest({
    required String message,
    required List<ProductModel> catalog,
  }) {
    final matches = resolveMany(message: message, catalog: catalog, limit: 1);
    return matches.isEmpty ? null : matches.first;
  }

  static int _scoreProductMention(String normalized, ProductModel product) {
    final normalizedBrand = CatalogProductMatcher.normalize(product.brand);
    final aliases = CatalogProductMatcher.termsFor(product).toSet()
      ..removeWhere((alias) => alias.isEmpty);

    for (final alias in aliases) {
      if (normalized == alias) return 500;
      if (alias.contains(' ') && normalized.contains(alias)) return 420;
    }

    final nameTokens = aliases
        .expand(_meaningfulTokens)
        .where((token) => token.length >= 2)
        .toSet()
        .toList(growable: false);
    if (nameTokens.isEmpty) return 0;
    final messageTokens = _meaningfulTokens(normalized).toSet();

    var matched = 0;
    var fuzzyMatched = 0;
    for (final token in nameTokens) {
      if (messageTokens.contains(token)) {
        matched++;
        continue;
      }
      if (_hasFuzzyToken(messageTokens, token)) {
        fuzzyMatched++;
      }
    }

    final totalMatched = matched + fuzzyMatched;
    if (totalMatched == 0) return 0;
    if (nameTokens.length > 1 && totalMatched < 2) return 0;

    var score = matched * 80 + fuzzyMatched * 55;
    if (normalizedBrand.isNotEmpty && messageTokens.contains(normalizedBrand)) {
      score += 40;
    }
    if (totalMatched == nameTokens.length) score += 80;
    return score;
  }

  static bool _hasFuzzyToken(Set<String> tokens, String term) {
    if (term.length < 5) return false;
    for (final token in tokens) {
      if (!parser_matchers.canUseFuzzyTokenMatch(token, term)) continue;
      if (parser_matchers.isWithinEditDistance(
        token,
        term,
        term.length >= 7 ? 2 : 1,
      )) {
        return true;
      }
    }
    return false;
  }

  static List<String> _meaningfulTokens(String value) {
    const stopwords = {
      'a',
      'an',
      'and',
      'available',
      'compare',
      'de',
      'do',
      'eau',
      'for',
      'fragrance',
      'have',
      'in',
      'is',
      'it',
      'la',
      'le',
      'of',
      'parfum',
      'perfume',
      'stock',
      'the',
      'this',
      'vs',
      'with',
      'you',
      'price',
      'cost',
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
    };
    return CatalogProductMatcher.normalize(value)
        .split(RegExp(r'\s+'))
        .expand((token) sync* {
          final trimmed = token.trim();
          if (trimmed.isEmpty) return;
          yield trimmed;
          final withoutArticle =
              CatalogProductMatcher.stripArabicArticleFromToken(trimmed);
          if (withoutArticle != trimmed) yield withoutArticle;
        })
        .where((token) => token.length >= 2)
        .where((token) => !stopwords.contains(token))
        .toSet()
        .toList(growable: false);
  }
}

class _MentionedProductCandidate {
  final ProductModel product;
  final int score;

  const _MentionedProductCandidate(this.product, this.score);
}
