import 'package:equatable/equatable.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<ProductModel> products;
  final bool hasMore;
  final bool isOfflineFallback;

  const SearchSuccess(
    this.products, {
    this.hasMore = false,
    this.isOfflineFallback = false,
  });

  @override
  List<Object> get props => [products, hasMore, isOfflineFallback];
}

class SearchLoadingMore extends SearchState {
  final List<ProductModel> currentProducts;

  const SearchLoadingMore(this.currentProducts);

  @override
  List<Object> get props => [currentProducts];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object> get props => [message];
}
