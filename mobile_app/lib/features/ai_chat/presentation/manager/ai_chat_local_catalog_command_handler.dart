import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_business_info.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_reply.dart';
import 'package:perfume_app/features/ai_chat/data/models/recommendation_memory.dart';
import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_reply_normalizer.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/availability_intent_utils.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_candidate_filter.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/local_intent_parser.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

class AIChatLocalCatalogCommandResult {
  final AIChatReply reply;
  final List<RecommendedProduct> recommendations;
  final String source;
  final String? reasonCode;
  final bool isAsk;

  const AIChatLocalCatalogCommandResult.answer({
    required this.reply,
    required this.source,
  }) : recommendations = const <RecommendedProduct>[],
       reasonCode = null,
       isAsk = false;

  const AIChatLocalCatalogCommandResult.ask({
    required this.reply,
    required this.source,
    required this.reasonCode,
  }) : recommendations = const <RecommendedProduct>[],
       isAsk = true;

  const AIChatLocalCatalogCommandResult.recommend({
    required this.reply,
    required this.recommendations,
    required this.source,
  }) : reasonCode = null,
       isAsk = false;
}

class AIChatLocalCatalogCommandHandler {
  final String Function(
    AIChatLanguage language, {
    required String ar,
    required String en,
  })
  translate;

  const AIChatLocalCatalogCommandHandler({required this.translate});

  Future<AIChatLocalCatalogCommandResult?> resolve({
    required String message,
    required AIChatLanguage language,
    required List<ProductModel> catalog,
    required SessionPreferences preferences,
    required RecommendationMemory recommendationMemory,
    required Future<Map<String, AIChatProductPublicStats>> Function()
    fetchProductPublicStats,
  }) async {
    final normalized = LocalIntentParser.normalizeInput(message);
    if (normalized.isEmpty) return null;

    final isLocalCatalogCommand =
        _looksLikeSuggestPerfumesCommand(normalized) ||
        _looksLikeAnyOtherCommand(normalized) ||
        _looksLikeMostSellingCommand(normalized) ||
        _looksLikeNewArrivalsCommand(normalized) ||
        AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized);
    if (!isLocalCatalogCommand &&
        LocalIntentParser.containsAny(
          normalized,
          AvailabilityIntentUtils.availabilityKeywords,
        )) {
      return null;
    }

    if (AvailabilityIntentUtils.looksLikeCatalogBrowseQuestion(normalized)) {
      return AIChatLocalCatalogCommandResult.answer(
        reply: AIChatReply.answer(
          answer: _buildCatalogBrowseAnswer(catalog, language),
          updatedPreferences: preferences,
        ),
        source: 'local_catalog_browse_answer',
      );
    }

    if (_looksLikeSuggestPerfumesCommand(normalized)) {
      final ready =
          preferences.canRecommendInitial ||
          preferences.canRecommendPracticalInitial;
      if (!ready) {
        return AIChatLocalCatalogCommandResult.ask(
          reply: AIChatReply.ask(
            question: translate(
              language,
              ar: '\u062a\u062d\u0628 \u0627\u0644\u0639\u0637\u0631 \u064a\u0643\u0648\u0646 \u0631\u062c\u0627\u0644\u064a \u0648\u0644\u0627 \u0646\u0633\u0627\u0626\u064a\u061f \u0648\u0644\u0648 \u0639\u0646\u062f\u0643 \u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0623\u0648 \u0646\u0648\u062a\u0629 \u0645\u0641\u0636\u0644\u0629 \u0642\u0648\u0644\u064a.',
              en: 'Tell me the gender, budget, or scent style you want and I will suggest matching perfumes.',
            ),
            updatedPreferences: preferences,
          ),
          source: 'local_generic_suggest_ask',
          reasonCode: 'generic_suggest_missing_preferences',
        );
      }

      final candidates = LocalCandidateFilter.getTopRecommendations(
        catalog: catalog,
        preferences: preferences,
      );
      if (candidates.isEmpty) return null;
      return AIChatLocalCatalogCommandResult.recommend(
        reply: buildRecommendReplyFromLocalCandidates(
          candidates,
          updatedPreferences: preferences,
        ),
        recommendations: candidates,
        source: 'local_generic_suggest_recommend',
      );
    }

    if (_looksLikeAnyOtherCommand(normalized)) {
      final limit = requestedPickLimit(normalized);
      final excludedIds = recommendationMemory.lastRecommendedProducts
          .map((ref) => ref.productId)
          .toSet();
      var candidates = LocalCandidateFilter.getTopRecommendations(
        catalog: catalog.where((p) => !excludedIds.contains(p.id)).toList(),
        preferences: preferences,
      ).take(limit).toList(growable: false);
      if (candidates.isEmpty) {
        candidates = _rankAvailableCatalogPicks(
          catalog,
          excludedIds: excludedIds,
          limit: limit,
          reason:
              'Another available catalog option, excluding the last cards I showed.',
        );
      }
      if (candidates.isEmpty) return null;
      return AIChatLocalCatalogCommandResult.recommend(
        reply: buildRecommendReplyFromLocalCandidates(
          candidates,
          updatedPreferences: preferences,
        ),
        recommendations: candidates,
        source: 'local_any_other_recommend',
      );
    }

    if (_looksLikeMostSellingCommand(normalized)) {
      final limit = requestedPickLimit(normalized);
      final stats = await fetchProductPublicStats();
      final picks = _rankBestSellingCatalogPicks(
        catalog,
        stats: stats,
        limit: limit,
      );
      if (picks.isEmpty) return null;
      return AIChatLocalCatalogCommandResult.recommend(
        reply: buildRecommendReplyFromLocalCandidates(
          picks,
          updatedPreferences: preferences,
        ),
        recommendations: picks,
        source: 'local_best_selling_picks',
      );
    }

    if (_looksLikeNewArrivalsCommand(normalized)) {
      final limit = requestedPickLimit(normalized);
      final picks = _rankNewestCatalogPicks(catalog, limit: limit);
      if (picks.isEmpty) return null;
      return AIChatLocalCatalogCommandResult.recommend(
        reply: buildRecommendReplyFromLocalCandidates(
          picks,
          updatedPreferences: preferences,
        ),
        recommendations: picks,
        source: 'local_new_arrivals',
      );
    }

    return null;
  }

  String _buildCatalogBrowseAnswer(
    List<ProductModel> catalog,
    AIChatLanguage language,
  ) {
    final genders = <String>{};
    final styles = <String>{};

    for (final product in catalog) {
      final gender = product.gender.trim().toLowerCase();
      if (gender.isNotEmpty) genders.add(gender);

      final family = product.fragranceFamily.toLowerCase();
      if (family.contains('fresh') ||
          family.contains('citrus') ||
          family.contains('aquatic')) {
        styles.add('fresh');
      }
      if (family.contains('woody') || family.contains('cedar')) {
        styles.add('woody');
      }
      if (family.contains('floral') ||
          family.contains('rose') ||
          family.contains('jasmine')) {
        styles.add('floral');
      }
      if (family.contains('oud') || family.contains('resin')) {
        styles.add('oud');
      }
      if (family.contains('amber') ||
          family.contains('vanilla') ||
          family.contains('gourmand')) {
        styles.add('amber/sweet');
      }
      if (family.contains('musk') || family.contains('clean')) {
        styles.add('clean/musky');
      }
    }

    final orderedGenders = <String>[
      if (genders.contains('men')) 'men',
      if (genders.contains('women')) 'women',
      if (genders.contains('unisex')) 'unisex',
    ];
    final orderedStyles = styles.toList(growable: false)..sort();

    if (language.isArabic) {
      final genderText = orderedGenders.isEmpty
          ? '\u0631\u062c\u0627\u0644\u064a \u0648\u0646\u0633\u0627\u0626\u064a \u0648\u064a\u0648\u0646\u064a\u0633\u0643\u0633'
          : orderedGenders
                .map((gender) => _arabicCatalogGender(gender))
                .join('\u060c ');
      final styleText = orderedStyles.isEmpty
          ? '\u0641\u0631\u064a\u0634\u060c \u062e\u0634\u0628\u064a\u060c \u0632\u0647\u0631\u064a\u060c \u0639\u0648\u062f\u064a\u060c \u0648\u062f\u0627\u0641\u0626'
          : orderedStyles.map(_arabicCatalogStyle).join('\u060c ');
      return '\u0644\u062f\u064a\u0646\u0627 \u0639\u0637\u0648\u0631 $genderText. \u0648\u0627\u0644\u0623\u0633\u0627\u0644\u064a\u0628 \u0627\u0644\u0645\u062a\u0627\u062d\u0629 \u062a\u0634\u0645\u0644 $styleText. \u0644\u0648 \u062a\u062d\u0628\u060c \u0623\u0642\u062f\u0631 \u0623\u0631\u0634\u062d \u0644\u0643 \u062d\u0633\u0628 \u0627\u0644\u062c\u0646\u0633 \u0623\u0648 \u0627\u0644\u0645\u0648\u0633\u0645 \u0623\u0648 \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629.';
    }

    final genderText = orderedGenders.isEmpty
        ? 'men, women, and unisex'
        : orderedGenders.join(', ');
    final styleText = orderedStyles.isEmpty
        ? 'fresh, woody, floral, oud, amber, and clean styles'
        : orderedStyles.join(', ');
    return 'We have $genderText perfumes. Main styles include $styleText. If you want, I can narrow it down by gender, season, or budget.';
  }

  String _arabicCatalogGender(String gender) {
    return switch (gender) {
      'men' => '\u0631\u062c\u0627\u0644\u064a',
      'women' => '\u0646\u0633\u0627\u0626\u064a',
      'unisex' => '\u064a\u0648\u0646\u064a\u0633\u0643\u0633',
      _ => gender,
    };
  }

  String _arabicCatalogStyle(String style) {
    return switch (style) {
      'fresh' => '\u0641\u0631\u064a\u0634',
      'woody' => '\u062e\u0634\u0628\u064a',
      'floral' => '\u0632\u0647\u0631\u064a',
      'oud' => '\u0639\u0648\u062f\u064a',
      'amber/sweet' => '\u062f\u0627\u0641\u0626/\u062d\u0644\u0648',
      'clean/musky' => '\u0646\u0638\u064a\u0641/\u0645\u0633\u0643\u064a',
      _ => style,
    };
  }

  bool _looksLikeSuggestPerfumesCommand(String normalized) {
    const genericSuggestCommands = {
      'suggest perfume',
      'suggest perfumes',
      'recommend perfume',
      'recommend perfumes',
      'suggest fragrance',
      'suggest fragrances',
      'recommend fragrance',
      'recommend fragrances',
    };
    return genericSuggestCommands.contains(normalized);
  }

  bool _looksLikeAnyOtherCommand(String normalized) {
    return normalized.contains('any other') ||
        normalized.contains('suggest other') ||
        normalized.contains('suggest another') ||
        normalized.contains('show me another') ||
        normalized.contains('show me other');
  }

  bool _looksLikeMostSellingCommand(String normalized) {
    final perfumeCue =
        normalized.contains('perfume') ||
        normalized.contains('perfumes') ||
        normalized.contains('fragrance') ||
        normalized.contains('fragrances') ||
        normalized.contains('\u0639\u0637\u0631') ||
        normalized.contains('\u0639\u0637\u0648\u0631');
    return normalized.contains('most selling') ||
        normalized.contains('most sold') ||
        normalized.contains('most popular') ||
        normalized.contains('popular') ||
        normalized.contains('top ordered') ||
        normalized.contains('top requested') ||
        normalized.contains('top selling') ||
        normalized.contains('best seller') ||
        normalized.contains('bestseller') ||
        normalized.contains('best perfume') ||
        normalized.contains('best fragrance') ||
        normalized.contains('top perfume') ||
        normalized.contains('top fragrance') ||
        (normalized.contains('best') && perfumeCue) ||
        normalized.contains(
          '\u0627\u0643\u062a\u0631 \u062d\u0627\u062c\u0629 \u0645\u0637\u0644\u0648\u0628\u0629',
        ) ||
        normalized.contains(
          '\u0627\u0643\u062b\u0631 \u062d\u0627\u062c\u0629 \u0645\u0637\u0644\u0648\u0628\u0629',
        ) ||
        normalized.contains(
          '\u0627\u0644\u0627\u0643\u062b\u0631 \u0637\u0644\u0628',
        ) ||
        normalized.contains(
          '\u0627\u0644\u0627\u0643\u062b\u0631 \u0645\u0628\u064a\u0639\u0627',
        ) ||
        normalized.contains('\u0627\u0634\u0647\u0631 \u0639\u0637\u0631') ||
        normalized.contains('\u0627\u062d\u0633\u0646 \u0639\u0637\u0631') ||
        normalized.contains('\u0627\u0641\u0636\u0644 \u0639\u0637\u0631') ||
        ((normalized.contains('\u0627\u062d\u0633\u0646') ||
                normalized.contains('\u0627\u0641\u0636\u0644')) &&
            perfumeCue);
  }

  bool _looksLikeNewArrivalsCommand(String normalized) {
    return normalized.contains('what is new') ||
        normalized.contains("what's new") ||
        normalized.contains('whats new') ||
        normalized.contains('what new') ||
        normalized.contains('new arrivals') ||
        normalized.contains('new arrival') ||
        normalized.contains('latest') ||
        normalized.contains('newest') ||
        normalized.contains('newest perfume') ||
        normalized.contains('newest perfumes') ||
        normalized.contains('newest fragrance') ||
        normalized.contains('newest fragrances') ||
        normalized.contains('new perfumes') ||
        normalized.contains('new fragrances') ||
        normalized.contains(
          '\u0627\u062c\u062f\u062f \u0627\u0644\u0639\u0637\u0648\u0631',
        ) ||
        normalized.contains(
          '\u0627\u062d\u062f\u062b \u0627\u0644\u0639\u0637\u0648\u0631',
        ) ||
        normalized.contains('\u0627\u0644\u062c\u062f\u064a\u062f') ||
        normalized.contains(
          '\u0627\u064a \u0627\u0644\u062c\u062f\u064a\u062f',
        ) ||
        normalized.contains(
          '\u0627\u064a\u0647 \u0627\u0644\u062c\u062f\u064a\u062f',
        );
  }

  List<RecommendedProduct> _rankAvailableCatalogPicks(
    List<ProductModel> catalog, {
    Set<String> excludedIds = const {},
    int limit = 3,
    required String reason,
  }) {
    final products =
        catalog
            .where(
              (product) =>
                  product.stock > 0 && !excludedIds.contains(product.id),
            )
            .toList()
          ..sort((a, b) {
            final byPrice = a.effectivePrice.compareTo(b.effectivePrice);
            if (byPrice != 0) return byPrice;
            return b.createdAt.toDate().compareTo(a.createdAt.toDate());
          });
    return products
        .take(limit)
        .map((product) {
          return RecommendedProduct(
            product: product,
            matchScore: 0.72,
            matchLabel: 'Available Pick',
            matchReason: reason,
          );
        })
        .toList(growable: false);
  }

  List<RecommendedProduct> _rankBestSellingCatalogPicks(
    List<ProductModel> catalog, {
    required Map<String, AIChatProductPublicStats> stats,
    int limit = 3,
  }) {
    final products = catalog.where((product) => product.stock > 0).toList();
    final hasRealStats = products.any((product) {
      return stats[product.id]?.hasSalesSignal == true;
    });

    if (hasRealStats) {
      products.sort((a, b) {
        final aStats = stats[a.id];
        final bStats = stats[b.id];
        final by30 = (bStats?.soldQty30d ?? 0).compareTo(
          aStats?.soldQty30d ?? 0,
        );
        if (by30 != 0) return by30;
        final by90 = (bStats?.soldQty90d ?? 0).compareTo(
          aStats?.soldQty90d ?? 0,
        );
        if (by90 != 0) return by90;
        final byAll = (bStats?.soldQtyAllTime ?? 0).compareTo(
          aStats?.soldQtyAllTime ?? 0,
        );
        if (byAll != 0) return byAll;
        return b.createdAt.toDate().compareTo(a.createdAt.toDate());
      });
      return products
          .take(limit)
          .map((product) {
            final entry = stats[product.id];
            final sold30 = entry?.soldQty30d ?? 0;
            final sold90 = entry?.soldQty90d ?? 0;
            final reason = sold30 > 0
                ? 'Frequently ordered recently based on delivered order data.'
                : sold90 > 0
                ? 'Frequently ordered in recent delivered order data.'
                : 'Frequently ordered based on delivered order history.';
            return RecommendedProduct(
              product: product,
              matchScore: sold30 > 0 ? 0.86 : 0.82,
              matchLabel: 'Most Ordered',
              matchReason: reason,
            );
          })
          .toList(growable: false);
    }

    final manuallyMarked =
        products.where((product) => product.isBestSeller).toList()..sort(
          (a, b) => b.createdAt.toDate().compareTo(a.createdAt.toDate()),
        );
    if (manuallyMarked.isNotEmpty) {
      return manuallyMarked
          .take(limit)
          .map((product) {
            return RecommendedProduct(
              product: product,
              matchScore: 0.78,
              matchLabel: 'Best Seller Pick',
              matchReason:
                  'Marked as a best seller in the catalog by the store team.',
            );
          })
          .toList(growable: false);
    }

    return _rankAvailableCatalogPicks(
      catalog,
      limit: limit,
      reason:
          'Available catalog pick. Sales metadata has not been published yet.',
    );
  }

  List<RecommendedProduct> _rankNewestCatalogPicks(
    List<ProductModel> catalog, {
    int limit = 3,
  }) {
    final products = catalog.where((product) => product.stock > 0).toList()
      ..sort((a, b) => b.createdAt.toDate().compareTo(a.createdAt.toDate()));
    return products
        .take(limit)
        .map((product) {
          return RecommendedProduct(
            product: product,
            matchScore: 0.74,
            matchLabel: 'New Arrival',
            matchReason: 'Newer available product from the catalog.',
          );
        })
        .toList(growable: false);
  }

  static int requestedPickLimit(String normalized) {
    const defaultLimit = 3;
    const maxLimit = 6;
    final digitMatches = RegExp(
      r'(?:^|[^\d])([1-6])(?:$|[^\d])',
    ).allMatches(normalized);
    for (final match in digitMatches) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= 1 && value <= maxLimit) return value;
    }

    const arabicDigits = <String, int>{
      '\u0661': 1,
      '\u0662': 2,
      '\u0663': 3,
      '\u0664': 4,
      '\u0665': 5,
      '\u0666': 6,
    };
    for (final entry in arabicDigits.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    final wordLimits = <String, int>{
      'one': 1,
      'single': 1,
      'only one': 1,
      'exactly one': 1,
      'one option': 1,
      'one pick': 1,
      'one recommendation': 1,
      'one perfume': 1,
      'two': 2,
      'couple': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      '\u0648\u0627\u062d\u062f': 1,
      '\u0648\u0627\u062d\u062f\u0629': 1,
      '\u0639\u0637\u0631 \u0648\u0627\u062d\u062f': 1,
      '\u0639\u0637\u0631\u064a\u0646': 2,
      '\u0627\u062a\u0646\u064a\u0646': 2,
      '\u0627\u062b\u0646\u064a\u0646': 2,
      '\u062a\u0646\u064a\u0646': 2,
      '\u062b\u0644\u0627\u062b': 3,
      '\u062b\u0644\u0627\u062b\u0629': 3,
      '\u062b\u0644\u0627\u062b\u0647': 3,
      '\u062a\u0644\u0627\u062a': 3,
      '\u062a\u0644\u0627\u062a\u0629': 3,
      '\u062a\u0644\u0627\u062a\u0647': 3,
      '\u0627\u0631\u0628\u0639\u0629': 4,
      '\u0627\u0631\u0628\u0639\u0647': 4,
      '\u062e\u0645\u0633\u0629': 5,
      '\u062e\u0645\u0633\u0647': 5,
      '\u0633\u062a\u0629': 6,
      '\u0633\u062a\u0647': 6,
    };
    for (final entry in wordLimits.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    return defaultLimit;
  }
}
