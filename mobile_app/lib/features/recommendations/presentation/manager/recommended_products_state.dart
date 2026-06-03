import 'package:perfume_app/features/products/data/models/product_model.dart';

enum RecommendedProductsStatus { initial, loading, success, empty, error }

enum RecommendationSource { behavioral, fallback }

class RecommendedProductsState {
  final RecommendedProductsStatus status;
  final List<ProductModel> products;
  final RecommendationSource? source;
  final String title;
  final String? errorMessage;

  const RecommendedProductsState({
    this.status = RecommendedProductsStatus.initial,
    this.products = const <ProductModel>[],
    this.source,
    this.title = '',
    this.errorMessage,
  });

  RecommendedProductsState copyWith({
    RecommendedProductsStatus? status,
    List<ProductModel>? products,
    Object? source = _unset,
    String? title,
    Object? errorMessage = _unset,
  }) {
    return RecommendedProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      source: source == _unset ? this.source : source as RecommendationSource?,
      title: title ?? this.title,
      errorMessage: errorMessage == _unset ? this.errorMessage : errorMessage as String?,
    );
  }

  static const Object _unset = Object();
}
