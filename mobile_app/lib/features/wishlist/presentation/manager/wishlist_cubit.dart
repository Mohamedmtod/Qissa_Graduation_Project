import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/wishlist/data/models/wishlist_item_model.dart';
import 'package:perfume_app/features/wishlist/data/repos/wishlist_repo.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';

part 'wishlist_state.dart';

class WishlistCubit extends Cubit<WishlistState> {
  final WishlistRepo wishlistRepo;
  final AuthBloc authBloc;
  final ProductRepo productRepo;
  StreamSubscription? _wishlistSubscription;
  StreamSubscription? _authSubscription;

  WishlistCubit({
    required this.wishlistRepo,
    required this.authBloc,
    required this.productRepo,
  }) : super(WishlistInitial()) {
    // Auto-init wishlist when auth state changes
    _authSubscription = authBloc.stream.listen((authState) {
      if (authState.status == AuthStatus.authenticated && authState.user != null) {
        _startListening(authState.user!.uid);
      } else {
        _wishlistSubscription?.cancel();
        emit(WishlistInitial());
      }
    });
    // Check current auth state immediately
    initWishlist();
  }

  void initWishlist() {
    final user = authBloc.state.user;
    if (user != null) {
      _startListening(user.uid);
    }
  }

  void _startListening(String uid) {
    emit(WishlistLoading());
    _wishlistSubscription?.cancel();
    _wishlistSubscription = wishlistRepo.streamWishlist(uid).listen(
      (items) async {
        try {
          final productIds = items.map((item) => item.productId).toList();
          final products = await productRepo.fetchProductsByIds(productIds);
          emit(WishlistLoaded(items: items, products: products));
        } catch (e) {
          emit(WishlistError('Failed to load wishlist products'));
        }
      },
      onError: (error) {
        emit(WishlistError(error.toString()));
      },
    );
  }

  Future<void> toggleWishlist(WishlistItemModel item) async {
    final user = authBloc.state.user;
    if (user == null) return;

    try {
      await wishlistRepo.toggleWishlist(user.uid, item);
    } catch (e) {
      // Error handled by repo/stream
    }
  }

  bool isWishlisted(String productId) {
    if (state is WishlistLoaded) {
      return (state as WishlistLoaded).items.any((item) => item.productId == productId);
    }
    return false;
  }

  @override
  Future<void> close() {
    _wishlistSubscription?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }
}
