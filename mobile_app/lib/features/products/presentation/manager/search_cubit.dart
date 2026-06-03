import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/products/presentation/manager/search_state.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';

class SearchCubit extends Cubit<SearchState> {
  final ProductRepo _productRepo;
  final EventRepo _eventRepo;
  final RecentlyViewedRepo _recentlyViewedRepo;

  Object? _lastDocument;

  // Current query/filter params
  String _currentQuery = '';
  String? _currentGender;
  String? _currentSeason;
  String? _currentFragranceFamily;
  bool _isFilterMode = false;

  String? _currentCategoryName;
  bool _isCategoryMode = false;
  bool _isRecentlyViewedMode = false;
  bool _isFlashSaleMode = false;
  List<String> _recentlyViewedIds = [];
  int _recentlyViewedLoadedCount = 0;

  int _opId = 0;

  static const int _searchLimit = 20;
  static const int _filterLimit = 20;
  static const int _recentlyViewedLimit = 10;

  SearchCubit(this._productRepo, this._eventRepo, this._recentlyViewedRepo)
    : super(SearchInitial());

  // ── Log Search (called only on submit) ─────────────────────────
  void logSearch(String query) {
    if (query.trim().isNotEmpty) {
      _eventRepo.logSearch(query);
    }
  }

  // ── Search by prefix (search-as-you-type) ───────────────────────
  Future<void> search(String query) async {
    final thisOp = ++_opId;

    if (query.trim().length < 2) {
      emit(SearchInitial());
      return;
    }

    _currentQuery = query;
    _isFilterMode = false;
    _isCategoryMode = false;
    _isRecentlyViewedMode = false;
    _isFlashSaleMode = false;
    _lastDocument = null;
    _currentGender = null;
    _currentSeason = null;
    _currentFragranceFamily = null;

    emit(SearchLoading());

    // REMOVED: _eventRepo.logSearch(query) to prevent spam writes

    try {
      final result = await _productRepo.searchByPrefix(
        query: query,
        limit: _searchLimit,
      );

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      emit(SearchSuccess(result.products, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      _emitLocalSearchFallback(query: query, error: e);
    }
  }

  // ── Filter by attributes ───────────────────────────────────────
  Future<void> filter({
    required String query,
    String? gender,
    String? season,
    String? fragranceFamily,
  }) async {
    final thisOp = ++_opId;

    _currentQuery = query;
    _currentGender = gender;
    _currentSeason = season;
    _currentFragranceFamily = fragranceFamily;
    _isFilterMode = true;
    _isCategoryMode = false;
    _isRecentlyViewedMode = false;
    _isFlashSaleMode = false;
    _lastDocument = null;

    emit(SearchLoading());

    try {
      final result = await _productRepo.filterProducts(
        query: query,
        gender: gender,
        season: season,
        fragranceFamily: fragranceFamily,
        limit: _filterLimit,
      );

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      emit(SearchSuccess(result.products, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      _emitLocalFilterFallback(
        query: query,
        gender: gender,
        season: season,
        fragranceFamily: fragranceFamily,
        error: e,
      );
    }
  }

  Future<void> filterWithinCategory({
    required String categoryName,
    String query = '',
    String? gender,
    String? season,
    String? fragranceFamily,
  }) async {
    final thisOp = ++_opId;

    _currentCategoryName = categoryName;
    _currentQuery = query;
    _currentGender = gender;
    _currentSeason = season;
    _currentFragranceFamily = fragranceFamily;
    _isFilterMode = true;
    _isCategoryMode = true;
    _isRecentlyViewedMode = false;
    _isFlashSaleMode = false;
    _lastDocument = null;

    emit(SearchLoading());

    try {
      final result = await _productRepo.filterProducts(
        query: query,
        categoryName: categoryName,
        gender: gender,
        season: season,
        fragranceFamily: fragranceFamily,
        limit: _filterLimit,
      );

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      emit(SearchSuccess(result.products, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      _emitLocalFilterFallback(
        query: query,
        categoryName: categoryName,
        gender: gender,
        season: season,
        fragranceFamily: fragranceFamily,
        error: e,
      );
    }
  }

  // ── Search by exact category name ──────────────────────────────
  Future<void> searchByCategory(String categoryName) async {
    final thisOp = ++_opId;

    _currentCategoryName = categoryName;
    _isCategoryMode = true;
    _isFilterMode = false;
    _isRecentlyViewedMode = false;
    _isFlashSaleMode = false;
    _currentQuery = '';
    _lastDocument = null;
    _currentGender = null;
    _currentSeason = null;
    _currentFragranceFamily = null;

    emit(SearchLoading());

    try {
      final result = await _productRepo.filterByCategory(
        categoryName: categoryName,
        limit: _filterLimit,
      );

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      emit(SearchSuccess(result.products, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      _emitLocalFilterFallback(categoryName: categoryName, error: e);
    }
  }

  Future<void> searchByViewedBefore() async {
    final thisOp = ++_opId;

    _isCategoryMode = false;
    _isFilterMode = false;
    _isRecentlyViewedMode = true;
    _isFlashSaleMode = false;
    _currentCategoryName = null;
    _currentQuery = '';
    _lastDocument = null;
    _currentGender = null;
    _currentSeason = null;
    _currentFragranceFamily = null;
    _recentlyViewedIds = [];
    _recentlyViewedLoadedCount = 0;

    emit(SearchLoading());
    debugPrint('🔄 SearchCubit: Loading recently viewed products...');

    try {
      _recentlyViewedIds = await _recentlyViewedRepo.getRecentlyViewedIds();
      final products = await _recentlyViewedRepo.getRecentlyViewedProducts(
        limit: _recentlyViewedLimit,
      );
      _recentlyViewedLoadedCount = products.length;

      if (thisOp != _opId) return;

      final hasMore = _recentlyViewedIds.length > _recentlyViewedLoadedCount;
      debugPrint(
        '✅ SearchCubit: Loaded ${products.length} recently viewed products (hasMore: $hasMore)',
      );
      emit(SearchSuccess(products, hasMore: hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      debugPrint('❌ SearchCubit: Error loading viewed-before: $e');
      emit(SearchError(e.toString()));
    }
  }

  Future<void> searchFlashSale() async {
    final thisOp = ++_opId;

    _isCategoryMode = false;
    _isFilterMode = false;
    _isRecentlyViewedMode = false;
    _isFlashSaleMode = true;
    _currentCategoryName = null;
    _currentQuery = '';
    _lastDocument = null;
    _currentGender = null;
    _currentSeason = null;
    _currentFragranceFamily = null;

    emit(SearchLoading());
    debugPrint('🔄 SearchCubit: Loading flash sale products...');

    try {
      final result = await _productRepo.getFlashSaleProducts(
        limit: _filterLimit,
      );

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      emit(SearchSuccess(result.products, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      debugPrint('❌ SearchCubit: Error loading flash sale: $e');
      _emitLocalFlashSaleFallback(error: e);
    }
  }

  void _emitLocalSearchFallback({
    required String query,
    required Object error,
  }) {
    try {
      final result = _productRepo.searchLocally(
        query: query,
        limit: _searchLimit,
      );
      _lastDocument = null;
      emit(
        SearchSuccess(result.products, hasMore: false, isOfflineFallback: true),
      );
    } catch (_) {
      emit(SearchError(error.toString()));
    }
  }

  void _emitLocalFilterFallback({
    String query = '',
    String? categoryName,
    String? gender,
    String? season,
    String? fragranceFamily,
    required Object error,
  }) {
    try {
      final result = _productRepo.filterLocally(
        query: query,
        categoryName: categoryName,
        gender: gender,
        season: season,
        fragranceFamily: fragranceFamily,
        limit: _filterLimit,
      );
      _lastDocument = null;
      emit(
        SearchSuccess(result.products, hasMore: false, isOfflineFallback: true),
      );
    } catch (_) {
      emit(SearchError(error.toString()));
    }
  }

  void _emitLocalFlashSaleFallback({required Object error}) {
    try {
      final result = _productRepo.flashSaleLocally(limit: _filterLimit);
      _lastDocument = null;
      emit(
        SearchSuccess(result.products, hasMore: false, isOfflineFallback: true),
      );
    } catch (_) {
      emit(SearchError(error.toString()));
    }
  }

  // ── Load more (pagination) ─────────────────────────────────────
  Future<void> loadMore() async {
    final thisOp = _opId;
    final currentState = state;
    if (currentState is! SearchSuccess || !currentState.hasMore) return;
    if (!_isRecentlyViewedMode && _lastDocument == null) return;
    if (currentState is SearchLoadingMore) {
      return; // Prevent concurrent loadMore
    }

    final existingProducts = List<ProductModel>.from(currentState.products);
    emit(SearchLoadingMore(existingProducts));

    try {
      ProductQueryResult result;

      if (_isRecentlyViewedMode) {
        final nextBatch = await _recentlyViewedRepo.getRecentlyViewedProducts(
          skip: _recentlyViewedLoadedCount,
          limit: _recentlyViewedLimit,
        );

        if (thisOp != _opId) return;

        _recentlyViewedLoadedCount += nextBatch.length;
        final mergedProducts = [...existingProducts, ...nextBatch];
        final hasMore = _recentlyViewedLoadedCount < _recentlyViewedIds.length;

        emit(SearchSuccess(mergedProducts, hasMore: hasMore));
        return;
      } else if (_isFlashSaleMode) {
        result = await _productRepo.getFlashSaleProducts(
          startAfterDocument: _lastDocument,
          limit: _filterLimit,
        );
      } else if (_isCategoryMode && _currentCategoryName != null) {
        if (_isFilterMode) {
          result = await _productRepo.filterProducts(
            query: _currentQuery,
            categoryName: _currentCategoryName,
            gender: _currentGender,
            season: _currentSeason,
            fragranceFamily: _currentFragranceFamily,
            startAfterDocument: _lastDocument,
            limit: _filterLimit,
          );
        } else {
          result = await _productRepo.filterByCategory(
            categoryName: _currentCategoryName!,
            startAfterDocument: _lastDocument,
            limit: _filterLimit,
          );
        }
      } else if (_isFilterMode) {
        result = await _productRepo.filterProducts(
          query: _currentQuery,
          gender: _currentGender,
          season: _currentSeason,
          fragranceFamily: _currentFragranceFamily,
          startAfterDocument: _lastDocument,
          limit: _filterLimit,
        );
      } else {
        result = await _productRepo.searchByPrefix(
          query: _currentQuery,
          startAfterDocument: _lastDocument,
          limit: _searchLimit,
        );
      }

      if (thisOp != _opId) return;

      _lastDocument = result.lastDocument;

      // Deduplicate by product ID to prevent UI glitches if DB has slightly overlapping results
      final allProducts = [...existingProducts, ...result.products];
      final seenIds = <String>{};
      final uniqueProducts = allProducts
          .where((p) => seenIds.add(p.id))
          .toList();

      emit(SearchSuccess(uniqueProducts, hasMore: result.hasMore));
    } catch (e) {
      if (thisOp != _opId) return;
      emit(SearchSuccess(existingProducts, hasMore: false));
    }
  }

  void reset() {
    _opId++;
    _lastDocument = null;
    emit(SearchInitial());
  }

  @override
  Future<void> close() {
    _opId++;
    return super.close();
  }
}
