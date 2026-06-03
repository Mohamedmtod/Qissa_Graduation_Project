import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_facet_index.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_query_detector.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class CatalogQueryServiceResult {
  final CatalogQuery query;
  final AIChatReply reply;
  final List<RecommendedProduct> recommendations;
  final SessionPreferences effectivePreferences;
  final String responseSource;
  final bool isNoMatch;
  final String? issueCode;
  final String? reasonCode;

  const CatalogQueryServiceResult({
    required this.query,
    required this.reply,
    required this.recommendations,
    required this.effectivePreferences,
    required this.responseSource,
    this.isNoMatch = false,
    this.issueCode,
    this.reasonCode,
  });

  bool get hasRecommendations => recommendations.isNotEmpty;
}

class CatalogQueryService {
  final CatalogQueryDetector detector;

  const CatalogQueryService({this.detector = const CatalogQueryDetector()});

  CatalogQueryServiceResult? resolve({
    required String message,
    required List<ProductModel> catalog,
    required SessionPreferences currentPreferences,
    required AIChatLanguage language,
  }) {
    currentPreferences;
    final query = detector.detect(message);
    if (query == null) return null;

    final index = CatalogFacetIndex.build(catalog);
    final engine = CatalogSearchEngine(catalog: catalog, facetIndex: index);
    final parsedPreferences = _parseConservativePreferences(message);
    final parsedFilters = _filtersFromPreferences(parsedPreferences);
    final filters = _filtersForQuery(
      query,
      parsedFilters,
      hasNumericBudget: RegExp(r'\d').hasMatch(message),
    );

    if ((query.type == CatalogQueryType.noteSearch ||
            query.type == CatalogQueryType.facetSearch) &&
        query.facetTerm != null &&
        !index.containsFacet(query.facetTerm!)) {
      return CatalogQueryServiceResult(
        query: query,
        reply: AIChatReply.answer(
          answer: _missingFacetMessage(query.facetTerm!, language),
          updatedPreferences: parsedPreferences,
          provider: 'local',
          modelId: 'catalog_query_service',
          promptVersion: 'catalog_query_v1',
        ),
        recommendations: const <RecommendedProduct>[],
        effectivePreferences: parsedPreferences,
        responseSource: 'local_catalog_query_no_exact_facet',
        isNoMatch: true,
        issueCode: 'catalog_facet_missing',
        reasonCode: 'catalog_facet_missing',
      );
    }

    final searchResults = engine.search(
      filters: filters,
      sort: query.sort,
      limit: query.limit,
    );
    final recommendations = searchResults
        .map(_recommendationFromSearchResult)
        .toList(growable: false);

    if (recommendations.isEmpty) {
      return CatalogQueryServiceResult(
        query: query,
        reply: AIChatReply.answer(
          answer: _noMatchMessage(language),
          updatedPreferences: parsedPreferences,
          provider: 'local',
          modelId: 'catalog_query_service',
          promptVersion: 'catalog_query_v1',
        ),
        recommendations: const <RecommendedProduct>[],
        effectivePreferences: parsedPreferences,
        responseSource: 'local_catalog_query_no_match',
        isNoMatch: true,
        issueCode: 'catalog_query_no_match',
        reasonCode: 'catalog_query_no_match',
      );
    }

    return CatalogQueryServiceResult(
      query: query,
      reply: AIChatReply.recommend(
        productIds: recommendations.map((item) => item.product.id).toList(),
        matchReasons: {
          for (final recommendation in recommendations)
            recommendation.product.id: recommendation.matchReason,
        },
        updatedPreferences: parsedPreferences,
        provider: 'local',
        modelId: 'catalog_query_service',
        promptVersion: 'catalog_query_v1',
      ),
      recommendations: recommendations,
      effectivePreferences: parsedPreferences,
      responseSource: _responseSourceFor(query.type),
    );
  }

  CatalogSearchFilters _filtersForQuery(
    CatalogQuery query,
    CatalogSearchFilters parsed, {
    required bool hasNumericBudget,
  }) {
    final facetTerm = query.facetTerm;
    if (query.type == CatalogQueryType.mostExpensive ||
        query.type == CatalogQueryType.cheapest ||
        query.type == CatalogQueryType.rankedByPrice) {
      return CatalogSearchFilters(
        gender: parsed.gender,
        minPrice: hasNumericBudget ? parsed.minPrice : null,
        maxPrice: hasNumericBudget ? parsed.maxPrice : null,
        season: parsed.season,
      );
    }

    return CatalogSearchFilters(
      gender: parsed.gender,
      minPrice: parsed.minPrice,
      maxPrice: parsed.maxPrice,
      season: parsed.season,
      occasion: parsed.occasion,
      time: parsed.time,
      intensity: parsed.intensity,
      notes: query.type == CatalogQueryType.noteSearch && facetTerm != null
          ? [facetTerm]
          : parsed.notes,
      tags: query.type == CatalogQueryType.facetSearch && facetTerm != null
          ? [facetTerm]
          : parsed.tags,
      family: parsed.family,
      brand: parsed.brand,
    );
  }

  CatalogSearchFilters _filtersFromPreferences(SessionPreferences parsed) {
    return CatalogSearchFilters(
      gender: parsed.gender,
      maxPrice: parsed.maxBudget,
      season: parsed.season,
      occasion: parsed.occasion,
      time: parsed.time,
      intensity: parsed.intensity,
      notes: [
        ...parsed.preferredNotes,
        ...parsed.preferredTopNotes,
        ...parsed.preferredMiddleNotes,
        ...parsed.preferredBaseNotes,
      ],
      tags: parsed.tags,
    );
  }

  SessionPreferences _parseConservativePreferences(String message) {
    // Current preferences intentionally do not constrain direct catalog queries.
    // A user asking "cheapest perfume you have" should query the whole catalog
    // unless the current message itself provides filters such as men/summer.
    final parsed = _safeParse(message);
    return SessionPreferences(
      gender: parsed.gender,
      maxBudget: parsed.maxBudget,
      season: parsed.season,
      occasion: parsed.occasion,
      time: parsed.time,
      intensity: parsed.intensity,
      preferredNotes: parsed.preferredNotes,
      preferredTopNotes: parsed.preferredTopNotes,
      preferredMiddleNotes: parsed.preferredMiddleNotes,
      preferredBaseNotes: parsed.preferredBaseNotes,
      tags: parsed.tags,
    );
  }

  SessionPreferences _safeParse(String message) {
    try {
      // Existing parser is reused only for structured scalar extraction.
      // Direct query detection remains conservative in CatalogQueryDetector.
      return LocalIntentParser.parse(message, SessionPreferences.empty());
    } catch (_) {
      return SessionPreferences.empty();
    }
  }

  RecommendedProduct _recommendationFromSearchResult(
    CatalogSearchResult result,
  ) {
    return RecommendedProduct(
      product: result.product,
      matchScore: result.matchScore,
      matchLabel: _matchLabel(result.matchScore),
      matchReason: result.matchReason,
      candidateSource: RecommendedCandidateSource.strict,
    );
  }

  String _matchLabel(double score) {
    if (score >= 0.80) return 'Closest Match';
    if (score >= 0.60) return 'Strong Match';
    return 'Catalog Match';
  }

  String _responseSourceFor(CatalogQueryType type) {
    switch (type) {
      case CatalogQueryType.mostExpensive:
        return 'local_catalog_query_most_expensive';
      case CatalogQueryType.cheapest:
        return 'local_catalog_query_cheapest';
      case CatalogQueryType.rankedByPrice:
        return 'local_catalog_query_ranked_by_price';
      case CatalogQueryType.noteSearch:
        return 'local_catalog_query_note_search';
      case CatalogQueryType.facetSearch:
        return 'local_catalog_query_facet_search';
    }
  }

  String _missingFacetMessage(String facetTerm, AIChatLanguage language) {
    final display = CatalogFacetIndex.normalizeText(facetTerm);
    if (language.isArabic) {
      return 'مش لاقي $display صريحة في الكتالوج الحالي. أقدر أقترح اختيارات fruity أو sweet من المتاح لو تحب.';
    }
    return 'I cannot find an explicit $display note in the current catalog. I can suggest available fruity or sweet alternatives if you want.';
  }

  String _noMatchMessage(AIChatLanguage language) {
    if (language.isArabic) {
      return 'مش لاقي منتج متاح يطابق طلبك مباشرة في الكتالوج الحالي.';
    }
    return 'I could not find an available catalog product that directly matches that request.';
  }
}
