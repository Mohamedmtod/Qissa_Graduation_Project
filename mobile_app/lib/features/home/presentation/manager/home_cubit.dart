import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/categories/data/models/category_model.dart';
import 'package:perfume_app/features/categories/data/repos/category_repo.dart';
import 'package:perfume_app/features/home/data/models/banner_model.dart';
import 'package:perfume_app/features/home/data/repositories/banner_repository.dart';
import 'package:perfume_app/features/home/presentation/manager/home_state.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';

class HomeCubit extends Cubit<HomeState> {
  static const Duration _staticContentTtl = Duration(hours: 24);
  static const Duration _flashSaleTtl = Duration(minutes: 10);

  static List<BannerModel>? _cachedBanners;
  static List<CategoryModel>? _cachedCategories;
  static List<ProductModel>? _cachedFlashSaleProducts;
  static DateTime? _bannersCachedAt;
  static DateTime? _categoriesCachedAt;
  static DateTime? _flashSaleCachedAt;
  static Future<_HomePayload>? _inFlightFetch;

  final ProductRepo productRepo;
  final BannerRepo bannerRepo;
  final CategoryRepo categoryRepo;

  List<BannerModel> _banners = [];
  List<CategoryModel> _categories = [];
  List<ProductModel> _flashSaleProducts = [];

  bool _bannersLoaded = false;
  bool _categoriesLoaded = false;
  bool _flashSaleLoaded = false;
  bool _isFlashSaleLoading = false;

  HomeCubit(this.productRepo, this.bannerRepo, this.categoryRepo)
    : super(HomeInitial());

  void fetchProducts() {
    if (state is HomeLoading) return;

    final cachedPayload = _cachedPayloadIfFresh();
    if (cachedPayload != null) {
      _applyPayload(cachedPayload);
      return;
    }

    emit(HomeLoading());
    unawaited(_fetchAndCacheProducts());
  }

  void _checkAndEmitSuccess() {
    if (_bannersLoaded && _categoriesLoaded && _flashSaleLoaded) {
      _emitSuccess();
    }
  }

  void _emitSuccess() {
    emit(
      HomeSuccess(
        banners: _banners,
        categories: _categories,
        flashSaleProducts: _flashSaleProducts,
        isFlashSaleLoading: _isFlashSaleLoading,
      ),
    );
  }

  void refresh() {
    _inFlightFetch = null;
    _bannersLoaded = false;
    _categoriesLoaded = false;
    _flashSaleLoaded = false;
    emit(HomeLoading());
    unawaited(_fetchAndCacheProducts(forceRefresh: true));
  }

  _HomePayload? _cachedPayloadIfFresh() {
    final now = DateTime.now();
    final banners = _cachedBanners;
    final categories = _cachedCategories;
    final flashSale = _cachedFlashSaleProducts;
    final bannersAt = _bannersCachedAt;
    final categoriesAt = _categoriesCachedAt;
    final flashSaleAt = _flashSaleCachedAt;
    if (banners == null ||
        categories == null ||
        flashSale == null ||
        bannersAt == null ||
        categoriesAt == null ||
        flashSaleAt == null) {
      return null;
    }

    final staticFresh =
        now.difference(bannersAt) <= _staticContentTtl &&
        now.difference(categoriesAt) <= _staticContentTtl;
    final flashFresh = now.difference(flashSaleAt) <= _flashSaleTtl;
    if (!staticFresh || !flashFresh) return null;

    return _HomePayload(
      banners: banners,
      categories: categories,
      flashSaleProducts: flashSale,
    );
  }

  Future<void> _fetchAndCacheProducts({bool forceRefresh = false}) async {
    try {
      final payload = await (_inFlightFetch ??= _loadHomePayload());
      if (forceRefresh) _inFlightFetch = null;
      if (isClosed) return;
      _applyPayload(payload);
      unawaited(_refreshFlashSaleProducts(payload));
    } catch (error) {
      _inFlightFetch = null;
      if (!isClosed) emit(HomeError(message: error.toString()));
    }
  }

  Future<_HomePayload> _loadHomePayload() async {
    final staticResults = await Future.wait<Object>([
      bannerRepo.getBanners(),
      categoryRepo.getCategories(),
    ]);
    final now = DateTime.now();
    final banners = staticResults[0] as List<BannerModel>;
    final categories = staticResults[1] as List<CategoryModel>;
    final cachedFlashSale = _cachedFlashSaleIfFresh();
    final flashSale = cachedFlashSale ?? const <ProductModel>[];

    _cachedBanners = banners;
    _cachedCategories = categories;
    _bannersCachedAt = now;
    _categoriesCachedAt = now;
    _inFlightFetch = null;

    debugPrint('HomeCubit: fetched static home payload.');
    return _HomePayload(
      banners: banners,
      categories: categories,
      flashSaleProducts: flashSale,
      isFlashSaleLoading: cachedFlashSale == null,
    );
  }

  List<ProductModel>? _cachedFlashSaleIfFresh() {
    final flashSale = _cachedFlashSaleProducts;
    final flashSaleAt = _flashSaleCachedAt;
    if (flashSale == null || flashSaleAt == null) return null;
    if (DateTime.now().difference(flashSaleAt) > _flashSaleTtl) return null;
    return flashSale;
  }

  Future<void> _refreshFlashSaleProducts(_HomePayload basePayload) async {
    try {
      final result = await productRepo.getFlashSaleProducts();
      if (isClosed) return;
      final updatedPayload = _HomePayload(
        banners: basePayload.banners,
        categories: basePayload.categories,
        flashSaleProducts: result.products,
        isFlashSaleLoading: false,
      );
      _cachedFlashSaleProducts = result.products;
      _flashSaleCachedAt = DateTime.now();
      _applyPayload(updatedPayload);
    } catch (error) {
      debugPrint('HomeCubit: flash sale load failed: $error');
    }
  }

  void _applyPayload(_HomePayload payload) {
    _banners = payload.banners;
    _categories = payload.categories;
    _flashSaleProducts = payload.flashSaleProducts;
    _isFlashSaleLoading = payload.isFlashSaleLoading;
    _bannersLoaded = true;
    _categoriesLoaded = true;
    _flashSaleLoaded = true;
    _checkAndEmitSuccess();
  }
}

class _HomePayload {
  final List<BannerModel> banners;
  final List<CategoryModel> categories;
  final List<ProductModel> flashSaleProducts;
  final bool isFlashSaleLoading;

  const _HomePayload({
    required this.banners,
    required this.categories,
    required this.flashSaleProducts,
    this.isFlashSaleLoading = false,
  });
}
