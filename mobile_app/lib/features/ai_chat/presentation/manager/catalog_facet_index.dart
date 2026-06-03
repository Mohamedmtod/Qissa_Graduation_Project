import 'package:perfume_app/features/products/data/models/product_model.dart';

enum CatalogFacetField {
  name,
  brand,
  family,
  notes,
  tags,
  description,
  gender,
  season,
  occasion,
  time,
  intensity,
  staffTags,
  staffWarnings,
  staffDna,
}

class CatalogFacetMatch {
  final String productId;
  final String query;
  final String normalizedQuery;
  final Set<CatalogFacetField> fields;

  const CatalogFacetMatch({
    required this.productId,
    required this.query,
    required this.normalizedQuery,
    required this.fields,
  });
}

class CatalogFacetEntry {
  final ProductModel product;
  final Map<CatalogFacetField, Set<String>> termsByField;

  CatalogFacetEntry({required this.product, required this.termsByField});

  Set<String> get allTerms {
    return {for (final terms in termsByField.values) ...terms};
  }

  Set<CatalogFacetField> fieldsMatchingAny(Set<String> queryTerms) {
    final fields = <CatalogFacetField>{};
    for (final entry in termsByField.entries) {
      if (queryTerms.any(entry.value.contains)) {
        fields.add(entry.key);
      }
    }
    return fields;
  }
}

class CatalogFacetIndex {
  final Map<String, CatalogFacetEntry> entriesByProductId;
  final Set<String> allFacetTerms;

  CatalogFacetIndex._({
    required this.entriesByProductId,
    required this.allFacetTerms,
  });

  factory CatalogFacetIndex.build(List<ProductModel> catalog) {
    final entries = <String, CatalogFacetEntry>{};
    final allTerms = <String>{};

    for (final product in catalog) {
      final entry = CatalogFacetEntry(
        product: product,
        termsByField: {
          CatalogFacetField.name: _termsFor([
            product.name,
            product.nameAr,
            ...product.aliases,
            ...product.aliasesAr,
          ]),
          CatalogFacetField.brand: _termsFor([product.brand, product.brandAr]),
          CatalogFacetField.family: _termsFor([product.fragranceFamily]),
          CatalogFacetField.notes: _termsFor([
            ...product.notes,
            ...product.topNotes,
            ...product.middleNotes,
            ...product.baseNotes,
            product.pyramidDescription ?? '',
          ]),
          CatalogFacetField.tags: _termsFor(product.tags),
          CatalogFacetField.description: _termsFor([product.description]),
          CatalogFacetField.gender: _termsFor([product.gender]),
          CatalogFacetField.season: _termsFor([product.season]),
          CatalogFacetField.occasion: _termsFor([product.occasion]),
          CatalogFacetField.time: _termsFor([product.time]),
          CatalogFacetField.intensity: _termsFor([product.intensity]),
          CatalogFacetField.staffTags: _termsFor(product.staffTagScores.keys),
          CatalogFacetField.staffWarnings: _termsFor(product.staffWarnings),
          CatalogFacetField.staffDna: _termsFor(product.similarFamousDna),
        },
      );
      entries[product.id] = entry;
      allTerms.addAll(entry.allTerms);
    }

    return CatalogFacetIndex._(
      entriesByProductId: entries,
      allFacetTerms: allTerms,
    );
  }

  CatalogFacetEntry? entryFor(ProductModel product) {
    return entriesByProductId[product.id];
  }

  bool containsFacet(String query) {
    final queryTerms = normalizeQueryTerms(query);
    if (queryTerms.isEmpty) return false;
    return queryTerms.any(allFacetTerms.contains);
  }

  List<CatalogFacetMatch> find(String query) {
    final queryTerms = normalizeQueryTerms(query);
    if (queryTerms.isEmpty) return const <CatalogFacetMatch>[];

    final matches = <CatalogFacetMatch>[];
    for (final entry in entriesByProductId.values) {
      final fields = entry.fieldsMatchingAny(queryTerms);
      if (fields.isEmpty) continue;
      matches.add(
        CatalogFacetMatch(
          productId: entry.product.id,
          query: query,
          normalizedQuery: queryTerms.firstWhere(
            entry.allTerms.contains,
            orElse: () => queryTerms.first,
          ),
          fields: fields,
        ),
      );
    }
    return matches;
  }

  Set<String> normalizeQueryTerms(String value) {
    final normalized = normalizeText(value);
    if (normalized.isEmpty) return const <String>{};
    return _expandedTermsForNormalized(normalized);
  }

  static Set<String> termsForValues(Iterable<String> values) {
    return _termsFor(values);
  }

  static String normalizeText(String value) {
    var normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '');
    normalized = normalized.replaceAll('\u0640', '');
    normalized = normalized
        .replaceAll(RegExp(r'[\u0623\u0625\u0622]'), '\u0627')
        .replaceAll('\u0649', '\u064a')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064a')
        .replaceAll('\u0629', '\u0647');
    normalized = normalized
        .replaceAll(RegExp(r'[^\w\s\u0621-\u064A\u0660-\u0669]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  static Set<String> _termsFor(Iterable<String> values) {
    final terms = <String>{};
    for (final value in values) {
      final normalized = normalizeText(value);
      if (normalized.isEmpty) continue;
      terms.addAll(_expandedTermsForNormalized(normalized));
      for (final token in normalized.split(' ')) {
        if (token.length < 2) continue;
        terms.addAll(_expandedTermsForNormalized(token));
        final withoutArticle = _stripArabicArticle(token);
        if (withoutArticle != token && withoutArticle.length >= 2) {
          terms.addAll(_expandedTermsForNormalized(withoutArticle));
        }
      }
    }
    return terms;
  }

  static Set<String> _expandedTermsForNormalized(String normalized) {
    final terms = <String>{normalized};
    final alias = _commonAliases[normalized];
    if (alias != null) terms.add(alias);
    return terms.where((term) => term.trim().isNotEmpty).toSet();
  }

  static String _stripArabicArticle(String value) {
    if (value.length <= 3) return value;
    return value.startsWith('\u0627\u0644') ? value.substring(2) : value;
  }

  static const Map<String, String> _commonAliases = {
    'strawberry': 'strawberry',
    '\u0641\u0631\u0627\u0648\u0644\u0647': 'strawberry',
    '\u0641\u0631\u0648\u0644\u0647': 'strawberry',
    '\u0633\u062a\u0631\u0648\u0628\u0631\u064a': 'strawberry',
    'powdery': 'powdery',
    '\u0628\u0648\u062f\u0631\u064a': 'powdery',
    '\u0628\u0648\u062f\u0631\u0647': 'powdery',
    'leather': 'leather',
    'leathery': 'leather',
    '\u062c\u0644\u062f\u064a': 'leather',
    '\u062c\u0644\u062f': 'leather',
    'tropical': 'tropical',
    '\u062a\u0631\u0648\u0628\u064a\u0643\u0627\u0644': 'tropical',
    '\u0627\u0633\u062a\u0648\u0627\u0626\u064a': 'tropical',
    'aquatic': 'aquatic',
    'marine': 'aquatic',
    '\u0645\u0627\u0626\u064a': 'aquatic',
    '\u0645\u0627\u064a\u064a': 'aquatic',
    '\u0628\u062d\u0631\u064a': 'aquatic',
    'citrus': 'citrus',
    'citrusy': 'citrus',
    'lemon': 'citrus',
    'orange': 'citrus',
    '\u062d\u0645\u0636\u064a': 'citrus',
    '\u062d\u0645\u0636\u064a\u0627\u062a': 'citrus',
    '\u0644\u064a\u0645\u0648\u0646': 'citrus',
    '\u0628\u0631\u062a\u0642\u0627\u0644': 'citrus',
    'musk': 'musk',
    'musky': 'musk',
    '\u0645\u0633\u0643': 'musk',
    '\u0645\u0633\u0643\u064a': 'musk',
    'oud': 'oud',
    '\u0639\u0648\u062f': 'oud',
    '\u0639\u0648\u062f\u064a': 'oud',
    'vanilla': 'vanilla',
    '\u0641\u0627\u0646\u064a\u0644\u064a\u0627': 'vanilla',
    '\u0641\u0627\u0646\u064a\u0644\u0627': 'vanilla',
    'rose': 'rose',
    '\u0648\u0631\u062f': 'rose',
    'jasmine': 'jasmine',
    '\u064a\u0627\u0633\u0645\u064a\u0646': 'jasmine',
    'chic': 'elegant',
    'classy': 'elegant',
    '\u0634\u064a\u0643': 'elegant',
    '\u0631\u0627\u0642\u064a': 'elegant',
    '\u0645\u0634 \u062e\u0627\u0646\u0642': 'not_cloying',
    '\u0645\u0634 \u0645\u0632\u0639\u062c': 'non_offensive',
    '\u0647\u0627\u062f\u064a \u0639\u0644\u0649 \u0627\u0644\u0627\u0646\u0641':
        'soft_on_nose',
    '\u0647\u0627\u062f\u064a \u0639\u0644\u0649 \u0627\u0644\u0623\u0646\u0641':
        'soft_on_nose',
    '\u0645\u0634 \u0628\u064a\u0648\u062c\u0639 \u0627\u0644\u062f\u0645\u0627\u063a':
        'not_headachey',
    '\u0647\u062f\u064a\u0647': 'gift',
    '\u0647\u062f\u064a\u0629': 'gift',
    '\u0627\u0645\u0627\u0646': 'safe_blind_buy',
    '\u0622\u0645\u0646': 'safe_blind_buy',
    'safe blind buy': 'safe_blind_buy',
    'not choking': 'not_cloying',
    'not headachey': 'not_headachey',
    'sauvage': 'sauvage_like',
    '\u0633\u0648\u0641\u0627\u062c': 'sauvage_like',
    'acqua di gio': 'acqua_di_gio_like',
    '\u0627\u0643\u0648\u0627': 'acqua_di_gio_like',
    'aventus': 'aventus_like',
    '\u0627\u0641\u064a\u0646\u062a\u0648\u0633': 'aventus_like',
    'good girl': 'good_girl_like',
    '\u062c\u0648\u062f \u062c\u064a\u0631\u0644': 'good_girl_like',
    'baccarat': 'baccarat_like',
    '\u0628\u0627\u0643\u0627\u0631\u0627\u062a': 'baccarat_like',
  };
}
