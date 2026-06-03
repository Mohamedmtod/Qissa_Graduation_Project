import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';

abstract class RecentlyViewedState {}

class RecentlyViewedInitial extends RecentlyViewedState {}

class RecentlyViewedLoading extends RecentlyViewedState {}

class RecentlyViewedSuccess extends RecentlyViewedState {
  final List<ProductModel> products;
  RecentlyViewedSuccess(this.products);
}

class RecentlyViewedEmpty extends RecentlyViewedState {}

class RecentlyViewedError extends RecentlyViewedState {
  final String message;
  RecentlyViewedError(this.message);
}

class RecentlyViewedCubit extends Cubit<RecentlyViewedState> {
  final RecentlyViewedRepo _repo;

  RecentlyViewedCubit(this._repo) : super(RecentlyViewedInitial());

  Future<void> loadRecentlyViewed({int limit = RecentlyViewedRepo.defaultPageSize}) async {
    emit(RecentlyViewedLoading());
    try {
      final products = await _repo.getRecentlyViewedProducts(limit: limit);
      if (products.isEmpty) {
        emit(RecentlyViewedEmpty());
      } else {
        emit(RecentlyViewedSuccess(products));
      }
    } catch (e) {
      emit(RecentlyViewedError(e.toString()));
    }
  }

  Future<void> refresh({int limit = RecentlyViewedRepo.defaultPageSize}) async {
    await loadRecentlyViewed(limit: limit);
  }
}
