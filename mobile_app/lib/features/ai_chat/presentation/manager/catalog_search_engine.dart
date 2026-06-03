import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_facet_index.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum CatalogSearchSort { bestMatch, cheapest, mostExpensive, strongest, newest }

class CatalogSearchFilters {
  final String? gender;
  final double? minPrice;
  final double? maxPrice;
  final String? season;
  final String? occasion;
  final String? time;
  final String? intensity;
  final List<String> notes;
  final List<String> tags;
  final String? family;
  final String? brand;
  final bool activeOnly;
  final bool inStockOnly;

  const CatalogSearchFilters({
    this.gender,
    this.minPrice,
    this.maxPrice,
    this.season,
    this.occasion,
    this.time,
    this.intensity,
    this.notes = const <String>[],
    this.tags = const <String>[],
    this.family,
    this.brand,
    this.activeOnly = true,
    this.inStockOnly = true,
  });

  bool get hasScoringSignals {
    return gender != null ||
        season != null ||
        occasion != null ||
        time != null ||
        intensity != null ||
        notes.isNotEmpty ||
        tags.isNotEmpty ||
        family != null ||
        brand != null;
  }
}

class CatalogSearchResult {
  final ProductModel product;
  final double matchScore;
  final List<String> matchedFacets;
  final List<String> reasonCodes;
  final String matchReason;

  const CatalogSearchResult({
    required this.product,
    required this.matchScore,
    required this.matchedFacets,
    required this.reasonCodes,
    required this.matchReason,
  });
}

class CatalogSearchEngine {
  final List<ProductModel> catalog;
  final CatalogFacetIndex facetIndex;

  CatalogSearchEngine({required this.catalog, CatalogFacetIndex? facetIndex})
    : facetIndex = facetIndex ?? CatalogFacetIndex.build(catalog);

  List<CatalogSearchResult> search({
    required CatalogSearchFilters filters,
    CatalogSearchSort sort = CatalogSearchSort.bestMatch,
    int? limit,
  }) {
    final results = <CatalogSearchResult>[];

    for (final product in catalog) {
      final entry = facetIndex.entryFor(product);
      if (entry == null) continue;
      if (!_passesHardFilters(product, entry, filters)) continue;
      results.add(_score(product, entry, filters));
    }

    results.sort((a, b) => _compareResults(a, b, sort));
    if (limit != null && results.length > limit) {
      return results.take(limit).toList(growable: false);
    }
    return results;
  }

  bool _passesHardFilters(
    ProductModel product,
    CatalogFacetEntry entry,
    CatalogSearchFilters filters,
  ) {
    if (filters.activeOnly && !product.isActive) return false;
    if (filters.inStockOnly && product.stock <= 0) return false;
    if (filters.minPrice != null &&
        product.effectivePrice < filters.minPrice!) {
      return false;
    }
    if (filters.maxPrice != null &&
        product.effectivePrice > filters.maxPrice!) {
      return false;
    }
    if (filters.gender != null &&
        !_genderMatches(filters.gender!, product.gender)) {
      return false;
    }
    if (filters.season != null &&
        !_flexibleScalarMatches(filters.season!, product.season, {
          'all_seasons',
          'all seasons',
        })) {
      return false;
    }
    if (filters.occasion != null &&
        !_normalizedEquals(filters.occasion!, product.occasion)) {
      return false;
    }
    if (filters.time != null &&
        !_flexibleScalarMatches(filters.time!, product.time, {
          'all_day',
          'all day',
        })) {
      return false;
    }
    if (filters.intensity != null &&
        !_normalizedEquals(filters.intensity!, product.intensity)) {
      return false;
    }
    if (filters.family != null &&
        !_fieldMatchesAll(entry, CatalogFacetField.family, [filters.family!])) {
      return false;
    }
    if (filters.brand != null &&
        !_fieldMatchesAll(entry, CatalogFacetField.brand, [filters.brand!])) {
      return false;
    }
    if (filters.notes.isNotEmpty &&
        !_scentFieldsMatchAll(entry, filters.notes)) {
      return false;
    }
    if (filters.tags.isNotEmpty &&
        !_fieldMatchesAll(entry, CatalogFacetField.tags, filters.tags)) {
      return false;
    }
    return true;
  }

  CatalogSearchResult _score(
    ProductModel product,
    CatalogFacetEntry entry,
    CatalogSearchFilters filters,
  ) {
    var score = 0.0;
    var possible = 0.0;
    final matchedFacets = <String>{};
    final reasons = <String>[];

    void addScalar({
      required String code,
      required String? requested,
      required String actual,
      double weight = 1.0,
      Set<String> flexible = const <String>{},
    }) {
      if (requested == null) return;
      possible += weight;
      if (_flexibleScalarMatches(requested, actual, flexible)) {
        score += weight;
        matchedFacets.add(code);
        reasons.add('${code}_matched');
      }
    }

    addScalar(
      code: 'gender',
      requested: filters.gender,
      actual: product.gender,
    );
    addScalar(
      code: 'season',
      requested: filters.season,
      actual: product.season,
      flexible: const {'all_seasons', 'all seasons'},
    );
    addScalar(
      code: 'occasion',
      requested: filters.occasion,
      actual: product.occasion,
    );
    addScalar(
      code: 'time',
      requested: filters.time,
      actual: product.time,
      flexible: const {'all_day', 'all day'},
    );
    addScalar(
      code: 'intensity',
      requested: filters.intensity,
      actual: product.intensity,
    );

    possible += filters.notes.length * 1.5;
    for (final note in filters.notes) {
      if (_scentFieldsMatchAny(entry, note)) {
        score += 1.5;
        matchedFacets.add('note:${_displayFacet(note)}');
        reasons.add('note_matched');
      }
    }

    possible += filters.tags.length;
    for (final tag in filters.tags) {
      if (_fieldMatchesAny(entry, CatalogFacetField.tags, tag)) {
        score += 1.0;
        matchedFacets.add('tag:${_displayFacet(tag)}');
        reasons.add('tag_matched');
      }
    }

    if (filters.family != null) {
      possible += 1.0;
      if (_fieldMatchesAny(entry, CatalogFacetField.family, filters.family!)) {
        score += 1.0;
        matchedFacets.add('family:${_displayFacet(filters.family!)}');
        reasons.add('family_matched');
      }
    }

    if (filters.brand != null) {
      possible += 1.0;
      if (_fieldMatchesAny(entry, CatalogFacetField.brand, filters.brand!)) {
        score += 1.0;
        matchedFacets.add('brand:${_displayFacet(filters.brand!)}');
        reasons.add('brand_matched');
      }
    }

    final normalizedScore = possible <= 0 ? 0.50 : (score / possible);
    final stockBoost = product.stock > 0 ? 0.03 : 0.0;
    final finalScore = (normalizedScore + stockBoost).clamp(0.0, 1.0);
    return CatalogSearchResult(
      product: product,
      matchScore: finalScore,
      matchedFacets: matchedFacets.toList(growable: false)..sort(),
      reasonCodes: reasons.toSet().toList(growable: false)..sort(),
      matchReason: _buildMatchReason(matchedFacets, filters),
    );
  }

  int _compareResults(
    CatalogSearchResult a,
    CatalogSearchResult b,
    CatalogSearchSort sort,
  ) {
    switch (sort) {
      case CatalogSearchSort.cheapest:
        return _chainCompare([
          a.product.effectivePrice.compareTo(b.product.effectivePrice),
          b.matchScore.compareTo(a.matchScore),
          a.product.name.compareTo(b.product.name),
        ]);
      case CatalogSearchSort.mostExpensive:
        return _chainCompare([
          b.product.effectivePrice.compareTo(a.product.effectivePrice),
          b.matchScore.compareTo(a.matchScore),
          a.product.name.compareTo(b.product.name),
        ]);
      case CatalogSearchSort.strongest:
        return _chainCompare([
          _intensityRank(
            b.product.intensity,
          ).compareTo(_intensityRank(a.product.intensity)),
          b.matchScore.compareTo(a.matchScore),
          b.product.effectivePrice.compareTo(a.product.effectivePrice),
          a.product.name.compareTo(b.product.name),
        ]);
      case CatalogSearchSort.newest:
        return _chainCompare([
          b.product.createdAt.compareTo(a.product.createdAt),
          b.matchScore.compareTo(a.matchScore),
          a.product.name.compareTo(b.product.name),
        ]);
      case CatalogSearchSort.bestMatch:
        return _chainCompare([
          b.matchScore.compareTo(a.matchScore),
          b.product.stock.compareTo(a.product.stock),
          a.product.effectivePrice.compareTo(b.product.effectivePrice),
          a.product.name.compareTo(b.product.name),
        ]);
    }
  }

  bool _fieldMatchesAll(
    CatalogFacetEntry entry,
    CatalogFacetField field,
    Iterable<String> queries,
  ) {
    return queries.every((query) => _fieldMatchesAny(entry, field, query));
  }

  bool _fieldMatchesAny(
    CatalogFacetEntry entry,
    CatalogFacetField field,
    String query,
  ) {
    final queryTerms = facetIndex.normalizeQueryTerms(query);
    if (queryTerms.isEmpty) return false;
    final fieldTerms = entry.termsByField[field] ?? const <String>{};
    return queryTerms.any(fieldTerms.contains);
  }

  bool _scentFieldsMatchAll(CatalogFacetEntry entry, Iterable<String> queries) {
    return queries.every((query) => _scentFieldsMatchAny(entry, query));
  }

  bool _scentFieldsMatchAny(CatalogFacetEntry entry, String query) {
    final queryTerms = facetIndex.normalizeQueryTerms(query);
    if (queryTerms.isEmpty) return false;
    final scentTerms = <String>{
      ...?entry.termsByField[CatalogFacetField.notes],
      ...?entry.termsByField[CatalogFacetField.tags],
      ...?entry.termsByField[CatalogFacetField.family],
      ...?entry.termsByField[CatalogFacetField.description],
    };
    return queryTerms.any(scentTerms.contains);
  }

  bool _genderMatches(String requested, String actual) {
    final requestedNorm = _normalizeScalar(requested);
    final actualNorm = _normalizeScalar(actual);
    if (requestedNorm.isEmpty || requestedNorm == 'unisex') return true;
    if (actualNorm.isEmpty || actualNorm == 'unisex') return true;
    return requestedNorm == actualNorm;
  }

  bool _flexibleScalarMatches(
    String requested,
    String actual,
    Set<String> flexibleValues,
  ) {
    final requestedNorm = _normalizeScalar(requested);
    final actualNorm = _normalizeScalar(actual);
    if (requestedNorm.isEmpty) return true;
    if (requestedNorm == actualNorm) return true;
    if (flexibleValues.contains(requestedNorm)) return true;
    return flexibleValues.contains(actualNorm);
  }

  bool _normalizedEquals(String requested, String actual) {
    final requestedNorm = _normalizeScalar(requested);
    if (requestedNorm.isEmpty) return true;
    return requestedNorm == _normalizeScalar(actual);
  }

  String _normalizeScalar(String value) {
    return CatalogFacetIndex.normalizeText(value).replaceAll(' ', '_');
  }

  String _displayFacet(String value) {
    return CatalogFacetIndex.normalizeText(value).replaceAll(' ', '_');
  }

  String _buildMatchReason(
    Set<String> matchedFacets,
    CatalogSearchFilters filters,
  ) {
    if (matchedFacets.isEmpty) {
      return filters.hasScoringSignals
          ? 'Available catalog result matching the required filters.'
          : 'Available catalog result.';
    }
    final items = matchedFacets.take(3).join(', ');
    return 'Matched catalog facets: $items.';
  }

  int _intensityRank(String intensity) {
    switch (_normalizeScalar(intensity)) {
      case 'strong':
        return 3;
      case 'medium':
        return 2;
      case 'light':
        return 1;
      default:
        return 0;
    }
  }

  int _chainCompare(List<int> comparisons) {
    for (final comparison in comparisons) {
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
