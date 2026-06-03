import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_candidate.dart';
import 'package:perfume_app/features/ai_chat/data/models/external_perfume_lookup_result.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

enum PerfumeReferenceStatus {
  resolved,
  needsClarification,
  notFound,
  cacheUnavailable,
}

enum PerfumeReferenceSource { catalog, perfumeKnowledge, externalLookup }

class PerfumeReferenceOption {
  final int index;
  final String name;
  final String brand;
  final PerfumeReferenceSource source;
  final String? productId;
  final String? externalProfileId;
  final ExternalPerfumeCandidate? externalCandidate;
  final double confidence;

  const PerfumeReferenceOption({
    required this.index,
    required this.name,
    required this.brand,
    required this.source,
    this.productId,
    this.externalProfileId,
    this.externalCandidate,
    this.confidence = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
      if (brand.trim().isNotEmpty) 'brand': brand,
      'source': source.name,
      if (productId != null) 'productId': productId,
      if (externalProfileId != null) 'externalProfileId': externalProfileId,
      if (confidence > 0) 'confidence': confidence,
    };
  }
}

class PerfumeReferenceResolution {
  final PerfumeReferenceStatus status;
  final PerfumeReferenceSource? source;
  final String query;
  final ProductModel? product;
  final PerfumeKnowledgeProfile? externalProfile;
  final List<PerfumeReferenceOption> options;
  final double confidence;
  final String? cacheStatus;
  final String? reason;

  const PerfumeReferenceResolution._({
    required this.status,
    required this.query,
    this.source,
    this.product,
    this.externalProfile,
    this.options = const [],
    this.confidence = 0,
    this.cacheStatus,
    this.reason,
  });

  const PerfumeReferenceResolution.catalog({
    required String query,
    required ProductModel product,
    required double confidence,
  }) : this._(
         status: PerfumeReferenceStatus.resolved,
         source: PerfumeReferenceSource.catalog,
         query: query,
         product: product,
         confidence: confidence,
       );

  const PerfumeReferenceResolution.externalProfile({
    required String query,
    required PerfumeKnowledgeProfile profile,
    required PerfumeReferenceSource source,
    required double confidence,
    String? cacheStatus,
  }) : this._(
         status: PerfumeReferenceStatus.resolved,
         source: source,
         query: query,
         externalProfile: profile,
         confidence: confidence,
         cacheStatus: cacheStatus,
       );

  const PerfumeReferenceResolution.clarification({
    required String query,
    required List<PerfumeReferenceOption> options,
    String? cacheStatus,
    String? reason,
  }) : this._(
         status: PerfumeReferenceStatus.needsClarification,
         query: query,
         options: options,
         cacheStatus: cacheStatus,
         reason: reason,
       );

  const PerfumeReferenceResolution.notFound({
    required String query,
    String? cacheStatus,
    String? reason,
  }) : this._(
         status: PerfumeReferenceStatus.notFound,
         query: query,
         cacheStatus: cacheStatus,
         reason: reason,
       );

  const PerfumeReferenceResolution.cacheUnavailable({
    required String query,
    String? reason,
  }) : this._(
         status: PerfumeReferenceStatus.cacheUnavailable,
         query: query,
         cacheStatus: 'cache_unavailable',
         reason: reason,
       );
}

typedef PerfumeKnowledgeLookup =
    Future<PerfumeKnowledgeProfile?> Function(String query);

typedef ExternalPerfumeLookup =
    Future<ExternalPerfumeLookupResult> Function({
      required String query,
      required AIChatLanguage responseLanguage,
      String? requestId,
    });

class PerfumeReferenceResolver {
  static const int defaultMaxOptions = 5;

  final PerfumeKnowledgeLookup? lookupKnowledge;
  final ExternalPerfumeLookup? lookupExternal;

  const PerfumeReferenceResolver({this.lookupKnowledge, this.lookupExternal});

  Future<PerfumeReferenceResolution> resolve({
    required String query,
    required List<ProductModel> catalog,
    required AIChatLanguage language,
    String? requestId,
    int maxOptions = defaultMaxOptions,
  }) async {
    final normalized = _normalize(query);
    if (normalized.length < 2) {
      return PerfumeReferenceResolution.notFound(
        query: query,
        reason: 'query_too_short',
      );
    }

    final catalogMatches = _catalogMatches(query, catalog);
    if (catalogMatches.exact.length == 1) {
      return PerfumeReferenceResolution.catalog(
        query: query,
        product: catalogMatches.exact.single.product,
        confidence: 0.96,
      );
    }
    if (catalogMatches.exact.length > 1) {
      return PerfumeReferenceResolution.clarification(
        query: query,
        options: _catalogOptions(catalogMatches.exact, maxOptions),
        reason: 'multiple_exact_catalog_matches',
      );
    }

    if (catalogMatches.strong.length == 1) {
      return PerfumeReferenceResolution.catalog(
        query: query,
        product: catalogMatches.strong.single.product,
        confidence: catalogMatches.strong.single.confidence,
      );
    }
    if (catalogMatches.strong.length > 1) {
      return PerfumeReferenceResolution.clarification(
        query: query,
        options: _catalogOptions(catalogMatches.strong, maxOptions),
        reason: 'multiple_catalog_matches',
      );
    }

    String? cacheStatus;
    if (lookupKnowledge != null) {
      try {
        final profile = await lookupKnowledge!(query);
        if (profile != null && profile.isUsable) {
          final confidence = profile.lookupConfidence.clamp(0, 1).toDouble();
          if (confidence >= 0.90 || _isExactProfileMatch(normalized, profile)) {
            return PerfumeReferenceResolution.externalProfile(
              query: query,
              profile: profile,
              source: PerfumeReferenceSource.perfumeKnowledge,
              confidence: confidence == 0 ? 0.90 : confidence,
              cacheStatus: 'cache_hit',
            );
          }
          return PerfumeReferenceResolution.clarification(
            query: query,
            options: [
              _profileOption(
                1,
                profile,
                PerfumeReferenceSource.perfumeKnowledge,
              ),
            ],
            cacheStatus: 'cache_hit',
            reason: 'knowledge_confidence_requires_confirmation',
          );
        }
        cacheStatus = 'cache_miss';
      } catch (_) {
        cacheStatus = 'cache_unavailable';
      }
    }

    if (lookupExternal != null) {
      final external = await lookupExternal!(
        query: query,
        responseLanguage: language,
        requestId: requestId,
      );
      if (external.isAmbiguous) {
        return PerfumeReferenceResolution.clarification(
          query: query,
          options: external.candidates
              .take(maxOptions)
              .toList(growable: false)
              .asMap()
              .entries
              .map(_externalCandidateOption)
              .toList(growable: false),
          cacheStatus: cacheStatus,
          reason: 'external_ambiguous',
        );
      }
      final profile = external.profile;
      if (profile != null && profile.isUsable) {
        final confidence = profile.lookupConfidence.clamp(0, 1).toDouble();
        if (confidence >= 0.90 || _isExactProfileMatch(normalized, profile)) {
          return PerfumeReferenceResolution.externalProfile(
            query: query,
            profile: profile,
            source: PerfumeReferenceSource.externalLookup,
            confidence: confidence == 0 ? 0.90 : confidence,
            cacheStatus: cacheStatus,
          );
        }
        return PerfumeReferenceResolution.clarification(
          query: query,
          options: [
            _profileOption(1, profile, PerfumeReferenceSource.externalLookup),
          ],
          cacheStatus: cacheStatus,
          reason: 'external_confidence_requires_confirmation',
        );
      }
    }

    if (cacheStatus == 'cache_unavailable') {
      return PerfumeReferenceResolution.cacheUnavailable(
        query: query,
        reason: 'perfume_knowledge_cache_unavailable',
      );
    }
    return PerfumeReferenceResolution.notFound(
      query: query,
      cacheStatus: cacheStatus,
      reason: 'reference_not_found',
    );
  }

  PerfumeReferenceOption? selectOption({
    required String userReply,
    required List<PerfumeReferenceOption> options,
  }) {
    final normalized = _normalize(userReply);
    if (normalized.isEmpty || options.isEmpty) return null;

    final ordinal = _ordinalSelectionIndex(normalized);
    if (ordinal != null && ordinal >= 0 && ordinal < options.length) {
      return options[ordinal];
    }

    final matches = options
        .where((option) {
          final name = _normalize(option.name);
          final brand = _normalize(option.brand);
          final label = _normalize('${option.brand} ${option.name}');
          if (normalized == name || normalized == label) return true;
          if (normalized.length >= 3 &&
              (name.contains(normalized) ||
                  label.contains(normalized) ||
                  brand == normalized)) {
            return true;
          }
          return false;
        })
        .toList(growable: false);

    return matches.length == 1 ? matches.single : null;
  }

  static PerfumeReferenceOption _profileOption(
    int index,
    PerfumeKnowledgeProfile profile,
    PerfumeReferenceSource source,
  ) {
    return PerfumeReferenceOption(
      index: index,
      name: profile.displayName,
      brand: profile.brand,
      source: source,
      externalProfileId: profile.id,
      confidence: profile.lookupConfidence,
    );
  }

  static PerfumeReferenceOption _externalCandidateOption(
    MapEntry<int, ExternalPerfumeCandidate> entry,
  ) {
    final candidate = entry.value;
    return PerfumeReferenceOption(
      index: entry.key + 1,
      name: candidate.displayName,
      brand: candidate.brand,
      source: PerfumeReferenceSource.externalLookup,
      externalProfileId: candidate.id,
      externalCandidate: candidate,
      confidence: candidate.score,
    );
  }

  static bool _isExactProfileMatch(
    String normalizedQuery,
    PerfumeKnowledgeProfile profile,
  ) {
    final keys = <String>{
      profile.displayName,
      if (profile.brand.trim().isNotEmpty)
        '${profile.brand} ${profile.displayName}',
      ...profile.aliases,
      ...profile.searchKeys,
    }.map(_normalize).where((item) => item.isNotEmpty).toSet();
    return keys.contains(normalizedQuery);
  }

  static List<PerfumeReferenceOption> _catalogOptions(
    List<_CatalogReferenceMatch> matches,
    int maxOptions,
  ) {
    return matches
        .take(maxOptions)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final product = entry.value.product;
          return PerfumeReferenceOption(
            index: entry.key + 1,
            name: product.name,
            brand: product.brand,
            source: PerfumeReferenceSource.catalog,
            productId: product.id,
            confidence: entry.value.confidence,
          );
        })
        .toList(growable: false);
  }

  static _CatalogReferenceMatches _catalogMatches(
    String query,
    List<ProductModel> catalog,
  ) {
    final normalizedQuery = _normalize(query);
    final exact = <_CatalogReferenceMatch>[];
    final strong = <_CatalogReferenceMatch>[];

    for (final product in catalog) {
      final names = _productReferenceKeys(product);
      if (names.contains(normalizedQuery)) {
        exact.add(_CatalogReferenceMatch(product, 0.96));
        continue;
      }

      final brand = _normalize(product.brand);
      final isBrandOnly = brand.isNotEmpty && normalizedQuery == brand;
      final containsQuery = names.any(
        (name) => normalizedQuery.length >= 3 && name.contains(normalizedQuery),
      );
      final queryContainsName = names.any(
        (name) => name.length >= 4 && normalizedQuery.contains(name),
      );
      if (isBrandOnly || containsQuery || queryContainsName) {
        final confidence = isBrandOnly ? 0.76 : 0.84;
        strong.add(_CatalogReferenceMatch(product, confidence));
      }
    }

    int compare(_CatalogReferenceMatch a, _CatalogReferenceMatch b) {
      final score = b.confidence.compareTo(a.confidence);
      if (score != 0) return score;
      return a.product.name.compareTo(b.product.name);
    }

    exact.sort(compare);
    strong.sort(compare);
    return _CatalogReferenceMatches(exact: exact, strong: strong);
  }

  static Set<String> _productReferenceKeys(ProductModel product) {
    return <String>{
      product.name,
      product.nameLower,
      if (product.nameAr.trim().isNotEmpty) product.nameAr,
      if (product.brand.trim().isNotEmpty) '${product.brand} ${product.name}',
      if (product.brandAr.trim().isNotEmpty)
        '${product.brandAr} ${product.nameAr}',
      ...product.aliases,
      ...product.aliasesAr,
    }.map(_normalize).where((item) => item.isNotEmpty).toSet();
  }

  static String _normalize(String value) {
    return AIChatTextNormalizer.normalizeForParsing(
      value,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _ordinalSelectionIndex(String normalized) {
    if (normalized == '\u0627\u0644\u0623\u0648\u0644' ||
        normalized == '\u0627\u0644\u0627\u0648\u0644' ||
        normalized == '\u0627\u0648\u0644' ||
        normalized == '\u0627\u0648\u0644 \u0648\u0627\u062d\u062f') {
      return 0;
    }
    if (normalized == '\u0627\u0644\u062b\u0627\u0646\u064a' ||
        normalized == '\u0627\u0644\u062a\u0627\u0646\u064a' ||
        normalized == '\u062a\u0627\u0646\u064a \u0648\u0627\u062d\u062f') {
      return 1;
    }
    if (normalized == '\u0627\u0644\u062b\u0627\u0644\u062b' ||
        normalized == '\u0627\u0644\u062a\u0627\u0644\u062a' ||
        normalized == '\u062a\u0627\u0644\u062a \u0648\u0627\u062d\u062f') {
      return 2;
    }
    if (RegExp(r'^(1|one|first|option 1|number 1|#1)$').hasMatch(normalized) ||
        normalized == 'الأول' ||
        normalized == 'اول' ||
        normalized == 'اول واحد') {
      return 0;
    }
    if (RegExp(r'^(2|two|second|option 2|number 2|#2)$').hasMatch(normalized) ||
        normalized == 'الثاني' ||
        normalized == 'التاني' ||
        normalized == 'تاني واحد') {
      return 1;
    }
    if (RegExp(
          r'^(3|three|third|option 3|number 3|#3)$',
        ).hasMatch(normalized) ||
        normalized == 'الثالث' ||
        normalized == 'التالت' ||
        normalized == 'تالت واحد') {
      return 2;
    }
    return null;
  }
}

class _CatalogReferenceMatches {
  final List<_CatalogReferenceMatch> exact;
  final List<_CatalogReferenceMatch> strong;

  const _CatalogReferenceMatches({required this.exact, required this.strong});
}

class _CatalogReferenceMatch {
  final ProductModel product;
  final double confidence;

  const _CatalogReferenceMatch(this.product, this.confidence);
}
