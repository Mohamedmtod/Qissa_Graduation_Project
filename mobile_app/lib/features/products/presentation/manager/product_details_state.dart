import 'package:perfume_app/features/products/data/models/product_model.dart';

abstract class ProductDetailsState {}

class ProductDetailsInitial extends ProductDetailsState {}

class ProductDetailsLoading extends ProductDetailsState {}

class ProductDetailsSuccess extends ProductDetailsState {
  final ProductModel product;

  ProductDetailsSuccess({required this.product});
}

class ProductDetailsUnavailable extends ProductDetailsState {
  final ProductModel product;

  ProductDetailsUnavailable({required this.product});
}

class ProductDetailsError extends ProductDetailsState {
  final String message;

  ProductDetailsError({required this.message});
}
