import 'package:perfume_app/features/home/data/models/banner_model.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/categories/data/models/category_model.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeSuccess extends HomeState {
  final List<BannerModel> banners;
  final List<CategoryModel> categories;
  final List<ProductModel> flashSaleProducts;
  final bool isFlashSaleLoading;

  HomeSuccess({
    required this.banners,
    required this.categories,
    required this.flashSaleProducts,
    this.isFlashSaleLoading = false,
  });
}

class HomeError extends HomeState {
  final String message;

  HomeError({required this.message});
}
