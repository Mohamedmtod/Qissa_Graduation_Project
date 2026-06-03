import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class CatalogProductMatcher {
  static final RegExp _diacritics = RegExp(r'[\u064B-\u0652\u0670]');

  static String normalize(String value) {
    var result = AIChatTextNormalizer.normalizeForParsing(value);
    result = result.replaceAll(_diacritics, '');
    result = result.replaceAll('\u0640', '');
    result = result
        .replaceAll(RegExp(r'[\u0623\u0625\u0622]'), '\u0627')
        .replaceAll('\u0649', '\u064a')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064a')
        .replaceAll('\u0629', '\u0647')
        .replaceAll(RegExp(r'[^\w\s\u0621-\u064A\u0660-\u0669]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return result;
  }

  static List<String> termsFor(ProductModel product) {
    final rawTerms = <String>[
      product.name,
      product.nameLower,
      product.nameAr,
      product.brand,
      product.brandAr,
      if (product.brand.trim().isNotEmpty && product.name.trim().isNotEmpty)
        '${product.brand} ${product.name}',
      if (product.brandAr.trim().isNotEmpty && product.nameAr.trim().isNotEmpty)
        '${product.brandAr} ${product.nameAr}',
      ...product.aliases,
      ...product.aliasesAr,
    ];

    final terms = <String>{};
    for (final raw in rawTerms) {
      final normalized = normalize(raw);
      if (normalized.isEmpty) continue;
      terms.add(normalized);
      terms.add(_stripArabicArticleFromPhrase(normalized));
    }
    terms.removeWhere((term) => term.isEmpty || term.length < 2);
    return terms.toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  static bool containsTerm(String normalizedText, String normalizedTerm) {
    if (normalizedText.isEmpty || normalizedTerm.isEmpty) return false;
    if (normalizedText == normalizedTerm) return true;
    return ' $normalizedText '.contains(' $normalizedTerm ');
  }

  static bool queryMentionsProduct(String query, ProductModel product) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return false;
    for (final term in termsFor(product)) {
      if (containsTerm(normalizedQuery, term)) return true;
      if (term.contains(' ') && containsTerm(term, normalizedQuery)) {
        return true;
      }
    }
    final queryTokens = meaningfulTokens(normalizedQuery, const {}).toSet();
    if (queryTokens.isEmpty) return false;
    for (final term in termsFor(product)) {
      final termTokens = meaningfulTokens(term, const {}).toSet();
      if (termTokens.isEmpty) continue;
      if (termTokens.any(queryTokens.contains)) return true;
    }
    return false;
  }

  static List<String> meaningfulTokens(String value, Set<String> stopwords) {
    return normalize(value)
        .split(RegExp(r'\s+'))
        .expand((token) sync* {
          if (token.isEmpty) return;
          yield token;
          final withoutArticle = stripArabicArticleFromToken(token);
          if (withoutArticle != token) yield withoutArticle;
        })
        .where((token) => token.length >= 2)
        .where((token) => !stopwords.contains(token))
        .toSet()
        .toList(growable: false);
  }

  static String stripArabicArticleFromToken(String token) {
    if (token.length <= 3) return token;
    return token.startsWith('\u0627\u0644') ? token.substring(2) : token;
  }

  static String _stripArabicArticleFromPhrase(String phrase) {
    return phrase
        .split(RegExp(r'\s+'))
        .map(stripArabicArticleFromToken)
        .join(' ')
        .trim();
  }
}
