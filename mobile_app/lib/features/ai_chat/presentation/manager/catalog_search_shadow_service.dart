import 'dart:convert';
import 'dart:io';

import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/budget_amount_parser.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/catalog_search_engine.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/suitability_policy_engine.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class CatalogSearchShadowResult {
  final List<RecommendedProduct> searchCandidates;
  final Map<String, dynamic> trace;

  const CatalogSearchShadowResult({
    required this.searchCandidates,
    required this.trace,
  });
}

class CatalogSearchShadowService {
  const CatalogSearchShadowService();

  CatalogSearchShadowResult compare({
    required String scenario,
    required String requestId,
    required List<ProductModel> catalog,
    required List<RecommendedProduct> oldCandidates,
    required SessionPreferences preferences,
    int limit = 15,
  }) {
    final searchCandidates = buildCandidates(
      catalog: catalog,
      preferences: preferences,
      limit: limit,
    );
    final oldIds = oldCandidates.map((item) => item.product.id).toList();
    final searchIds = searchCandidates.map((item) => item.product.id).toList();
    final oldIdSet = oldIds.toSet();
    final searchIdSet = searchIds.toSet();
    final suitabilityResults = const SuitabilityPolicyEngine().evaluateProducts(
      products: searchCandidates.map((item) => item.product).toList(),
      context: SuitabilityContext(
        preferences: preferences,
        hasExplicitBudget: BudgetAmountParser.containsBudgetNumber(scenario),
        sourcePath: 'catalog_search_shadow',
      ),
    );

    final trace = <String, dynamic>{
      'scenario': scenario,
      'oldCandidateIds': oldIds,
      'searchCandidateIds': searchIds,
      'overlapCount': oldIdSet.intersection(searchIdSet).length,
      'searchWouldHaveDroppedIds': oldIds
          .where((id) => !searchIdSet.contains(id))
          .toList(growable: false),
      'suitabilityReasons': {
        for (final entry in suitabilityResults.entries)
          entry.key: entry.value.suitabilityReasons,
      },
      'suitabilityScores': {
        for (final entry in suitabilityResults.entries)
          entry.key: entry.value.suitabilityScore,
      },
      'blockedBySuitability': {
        for (final entry in suitabilityResults.entries)
          entry.key: entry.value.blockedBySuitability,
      },
    };

    return CatalogSearchShadowResult(
      searchCandidates: searchCandidates,
      trace: trace,
    );
  }

  Future<void> writeArtifact({
    required String requestId,
    required Map<String, dynamic> trace,
    String directoryPath = 'test_artifacts/ai_chat_search_shadow',
  }) async {
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    final safeRequestId = requestId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/$safeRequestId.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(trace)}\n');
  }

  List<RecommendedProduct> buildCandidates({
    required List<ProductModel> catalog,
    required SessionPreferences preferences,
    required int limit,
  }) {
    final engine = CatalogSearchEngine(catalog: catalog);
    var results = engine.search(
      filters: CatalogSearchFilters(
        gender: preferences.gender,
        maxPrice: preferences.maxBudget,
        season: preferences.season,
        occasion: preferences.occasion,
        time: preferences.time,
        intensity: preferences.intensity,
        notes: [
          ...preferences.preferredNotes,
          ...preferences.preferredTopNotes,
          ...preferences.preferredMiddleNotes,
          ...preferences.preferredBaseNotes,
        ],
        tags: preferences.tags,
      ),
      sort: _sortFor(preferences),
      limit: limit,
    );
    if (results.isEmpty &&
        (preferences.occasion != null ||
            preferences.time != null ||
            preferences.intensity != null)) {
      results = engine.search(
        filters: CatalogSearchFilters(
          gender: preferences.gender,
          maxPrice: preferences.maxBudget,
          season: preferences.season,
          notes: [
            ...preferences.preferredNotes,
            ...preferences.preferredTopNotes,
            ...preferences.preferredMiddleNotes,
            ...preferences.preferredBaseNotes,
          ],
          tags: preferences.tags,
        ),
        sort: _sortFor(preferences),
        limit: limit,
      );
    }

    return results
        .map(
          (result) => RecommendedProduct(
            product: result.product,
            matchScore: result.matchScore,
            matchLabel: _matchLabel(result.matchScore),
            matchReason: result.matchReason,
            candidateSource: RecommendedCandidateSource.strict,
          ),
        )
        .toList(growable: false);
  }

  CatalogSearchSort _sortFor(SessionPreferences preferences) {
    switch (preferences.rankingStrategy) {
      case RankingStrategy.cheapestFirst:
        return CatalogSearchSort.cheapest;
      case RankingStrategy.expensiveFirst:
        return CatalogSearchSort.mostExpensive;
      case null:
        return CatalogSearchSort.bestMatch;
    }
  }

  String _matchLabel(double score) {
    if (score >= 0.80) return 'Closest Match';
    if (score >= 0.60) return 'Strong Match';
    return 'Catalog Match';
  }
}
