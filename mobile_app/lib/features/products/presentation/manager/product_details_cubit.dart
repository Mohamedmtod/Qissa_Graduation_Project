import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/recommendations/data/models/event_type.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_state.dart';

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final ProductRepo productRepo;
  final EventRepo eventRepo;
  final RecentlyViewedRepo recentlyViewedRepo;
  final UserTasteRepo? userTasteRepo;
  StreamSubscription? _productSubscription;
  bool _hasTrackedView = false;

  ProductDetailsCubit(
    this.productRepo,
    this.eventRepo,
    this.recentlyViewedRepo,
    this.userTasteRepo,
  ) : super(ProductDetailsInitial());

  void watchProduct(String id, {Future<void> Function()? onViewAdded}) {
    emit(ProductDetailsLoading());
    _hasTrackedView = false;

    _productSubscription?.cancel();
    _productSubscription = productRepo
        .streamProductById(id)
        .listen(
          (product) {
            if (product != null) {
              if (!product.isActive) {
                emit(ProductDetailsUnavailable(product: product));
                return;
              }

              emit(ProductDetailsSuccess(product: product));

              if (!_hasTrackedView) {
                _hasTrackedView = true;
                debugPrint(
                  '📱 ProductDetailsCubit: Viewing product ${product.id} (${product.name})',
                );
                unawaited(() async {
                  await recentlyViewedRepo.addView(product.id);
                  await onViewAdded?.call();
                }());
                unawaited(
                  Future<void>(() async {
                    try {
                      await eventRepo.logProductView(
                        productId: product.id,
                        name: product.name,
                        price: product.effectivePrice,
                      );
                    } catch (_) {
                      // Non-blocking analytics.
                    }

                    try {
                      await userTasteRepo?.recordEvent(
                        eventType: EventType.view,
                        notes: product.notes,
                      );
                    } catch (_) {
                      // Non-blocking local tracking.
                    }
                  }),
                );
              }
            } else {
              emit(ProductDetailsError(message: "Product not found"));
            }
          },
          onError: (error) {
            emit(ProductDetailsError(message: error.toString()));
          },
        );
  }

  @override
  Future<void> close() {
    _productSubscription?.cancel();
    return super.close();
  }
}
