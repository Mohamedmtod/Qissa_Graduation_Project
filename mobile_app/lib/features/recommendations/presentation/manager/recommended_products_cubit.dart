import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/presentation/manager/recommended_products_state.dart';

class RecommendedProductsCubit extends Cubit<RecommendedProductsState> {
  final ProductRepo _productRepo;
  final UserTasteRepo _userTasteRepo;

  RecommendedProductsCubit({
    required ProductRepo productRepo,
    required UserTasteRepo userTasteRepo,
  }) : _productRepo = productRepo,
       _userTasteRepo = userTasteRepo,
       super(const RecommendedProductsState());

  Future<void> load({String? excludeProductId, int limit = 6}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: RecommendedProductsStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final topNotes = await _userTasteRepo.getTopNotes(limit: 2);
      if (isClosed) return;
      final catalog = (await _productRepo.fetchAICatalog())
          .where((product) => product.isActive)
          .toList();
      if (isClosed) return;

      if (topNotes.isEmpty) {
        final fallback = _fallbackProducts(
          catalog,
          excludeProductId: excludeProductId,
          limit: limit,
        );

        if (fallback.isEmpty) {
          if (isClosed) return;
          emit(
            state.copyWith(
              status: RecommendedProductsStatus.empty,
              source: RecommendationSource.fallback,
              products: const <ProductModel>[],
            ),
          );
          return;
        }

        if (isClosed) return;
        emit(
          state.copyWith(
            status: RecommendedProductsStatus.success,
            source: RecommendationSource.fallback,
            products: fallback,
          ),
        );
        return;
      }

      final tasteProfile = await _userTasteRepo.getTasteProfile();
      if (isClosed) return;
      final behavioral = _behavioralProducts(
        catalog,
        topNotes: topNotes,
        noteScores: tasteProfile.noteScores,
        excludeProductId: excludeProductId,
        limit: limit,
      );

      if (behavioral.isEmpty) {
        final fallback = _fallbackProducts(
          catalog,
          excludeProductId: excludeProductId,
          limit: limit,
        );

        if (fallback.isEmpty) {
          if (isClosed) return;
          emit(
            state.copyWith(
              status: RecommendedProductsStatus.empty,
              source: RecommendationSource.fallback,
              products: const <ProductModel>[],
            ),
          );
          return;
        }

        if (isClosed) return;
        emit(
          state.copyWith(
            status: RecommendedProductsStatus.success,
            source: RecommendationSource.fallback,
            products: fallback,
          ),
        );
        return;
      }

      if (isClosed) return;
      emit(
        state.copyWith(
          status: RecommendedProductsStatus.success,
          source: RecommendationSource.behavioral,
          products: behavioral,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: RecommendedProductsStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  List<ProductModel> _fallbackProducts(
    List<ProductModel> catalog, {
    required String? excludeProductId,
    required int limit,
  }) {
    final items = catalog
        .where(
          (product) =>
              excludeProductId == null || product.id != excludeProductId,
        )
        .toList();

    items.sort((a, b) {
      final stockCompare = _inStockRank(b).compareTo(_inStockRank(a));
      if (stockCompare != 0) return stockCompare;

      final saleCompare = _saleRank(b).compareTo(_saleRank(a));
      if (saleCompare != 0) return saleCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    return items.take(limit).toList();
  }

  List<ProductModel> _behavioralProducts(
    List<ProductModel> catalog, {
    required List<String> topNotes,
    required Map<String, double> noteScores,
    required String? excludeProductId,
    required int limit,
  }) {
    final topSet = topNotes.toSet();
    final scored = <_RankedProduct>[];

    for (final product in catalog) {
      if (excludeProductId != null && product.id == excludeProductId) {
        continue;
      }

      final noteMatches = product.notes
          .map((note) => note.trim().toLowerCase())
          .where(topSet.contains)
          .toSet();
      final tagMatches = product.tags
          .map((tag) => tag.trim().toLowerCase())
          .where(topSet.contains)
          .toSet();

      final totalMatches = noteMatches.length + tagMatches.length;
      if (totalMatches == 0) continue;

      final weightedScore = <String>{
        ...noteMatches,
        ...tagMatches,
      }.fold<double>(0, (sum, note) => sum + (noteScores[note] ?? 0));

      scored.add(
        _RankedProduct(
          product: product,
          matchCount: totalMatches,
          weightedScore: weightedScore,
        ),
      );
    }

    scored.sort((a, b) {
      final stockCompare = _inStockRank(
        b.product,
      ).compareTo(_inStockRank(a.product));
      if (stockCompare != 0) return stockCompare;

      final saleCompare = _saleRank(b.product).compareTo(_saleRank(a.product));
      if (saleCompare != 0) return saleCompare;

      final matchCompare = b.matchCount.compareTo(a.matchCount);
      if (matchCompare != 0) return matchCompare;

      final weightCompare = b.weightedScore.compareTo(a.weightedScore);
      if (weightCompare != 0) return weightCompare;

      return b.product.createdAt.compareTo(a.product.createdAt);
    });

    return scored.take(limit).map((item) => item.product).toList();
  }

  int _inStockRank(ProductModel product) => product.stock > 0 ? 1 : 0;

  int _saleRank(ProductModel product) => product.isOnSale ? 1 : 0;
}

class _RankedProduct {
  final ProductModel product;
  final int matchCount;
  final double weightedScore;

  const _RankedProduct({
    required this.product,
    required this.matchCount,
    required this.weightedScore,
  });
}
