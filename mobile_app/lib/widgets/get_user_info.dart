import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/add_to_cart_cubit.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_cubit.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_state.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class UserIdentityData {
  final String name;
  final String email;

  const UserIdentityData({required this.name, required this.email});
}

class GetUserInfo extends StatelessWidget {
  const GetUserInfo({super.key, required this.builder});

  final Widget Function(BuildContext context, UserIdentityData data) builder;

  @override
  Widget build(BuildContext context) {
    final authUser = context.select((AuthBloc bloc) => bloc.state.user);

    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        final user = _userFromState(state);
        final name = user == null
            ? (authUser?.displayName ?? '')
            : '${user.firstName} ${user.lastName}'.trim();
        final email = user?.email ?? authUser?.email ?? '';

        return builder(context, UserIdentityData(name: name, email: email));
      },
    );
  }

  UserModel? _userFromState(UserState state) {
    if (state is UserLoaded) return state.user;
    if (state is UserUpdating) return state.user;
    if (state is UserUpdateSuccess) return state.user;
    if (state is UserError) return state.user;
    return null;
  }
}

typedef AddressWidgetBuilder =
    Widget Function(BuildContext context, AddressModel? address);

class GetUserAddress extends StatefulWidget {
  const GetUserAddress({
    super.key,
    required this.builder,
    this.onAddressChanged,
  });

  final AddressWidgetBuilder builder;
  final void Function(AddressModel? address)? onAddressChanged;

  @override
  State<GetUserAddress> createState() => _GetUserAddressState();

  /// Static helper to update the global manual address
  static void setAddress(BuildContext context, AddressModel? address) {
    context.read<AddressCubit>().setSelectedAddress(address);
  }
}

class _GetUserAddressState extends State<GetUserAddress> {
  @override
  void initState() {
    super.initState();
    // Notify parent of initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyEffectiveAddress();
    });
  }

  void _notifyEffectiveAddress() {
    if (!mounted) return;
    final state = context.read<AddressCubit>().state;
    final effective = state.selectedAddress ?? state.defaultAddress;
    widget.onAddressChanged?.call(effective);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddressCubit, AddressState>(
      listenWhen: (prev, curr) =>
          prev.defaultAddress != curr.defaultAddress ||
          prev.selectedAddress != curr.selectedAddress,
      listener: (context, state) {
        // Notify whenever the effective address changes globally
        final effective = state.selectedAddress ?? state.defaultAddress;
        widget.onAddressChanged?.call(effective);
      },
      child: BlocBuilder<AddressCubit, AddressState>(
        builder: (context, state) {
          final effectiveAddress =
              state.selectedAddress ?? state.defaultAddress;
          return widget.builder(context, effectiveAddress);
        },
      ),
    );
  }
}

class AddtoCartButtondata {
  final bool isLoading;

  const AddtoCartButtondata({required this.isLoading});
}

class AddtoCartButton extends StatelessWidget {
  const AddtoCartButton({super.key, required this.builder});

  final Widget Function(BuildContext context, AddtoCartButtondata data) builder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        UserTasteRepo? tasteRepo;
        try {
          tasteRepo = RepositoryProvider.of<UserTasteRepo>(context);
        } catch (_) {
          tasteRepo = null;
        }

        return AddToCartCubit(
          cartRepo: RepositoryProvider.of<CartRepo>(context),
          eventRepo: RepositoryProvider.of<EventRepo>(context),
          userTasteRepo: tasteRepo,
        );
      },
      child: BlocConsumer<AddToCartCubit, AddToCartState>(
        listener: (context, cartState) {
          final l10n = AppLocalizations.of(context);
          if (cartState is AddToCartSuccess) {
            // AppSnackBar.showSuccess(context, l10n.msgAddedToCartSuccessfully);
          } else if (cartState is AddToCartError) {
            AppSnackBar.showError(
              context,
              resolveUserFacingMessage(
                context,
                cartState.message,
                fallback: l10n.msgAddToCartFailed,
              ),
            );
          }
        },
        builder: (context, cartState) {
          final isLoading = cartState is AddToCartLoading;

          return builder(context, AddtoCartButtondata(isLoading: isLoading));
        },
      ),
    );
  }
}




                                   
                                
                                      // return ElevatedButton(
                                      //   onPressed: (product.stock > 0 &&
                                      //           !isLoading)
                                      //       ? () {
                                            //     final user = FirebaseAuth
                                            //         .instance.currentUser;
                                            //     if (user == null) {
                                            //       ScaffoldMessenger.of(context)
                                            //           .showSnackBar(
                                            //         const SnackBar(
                                            //           content: Text(
                                            //               'Please login to add items to cart'),
                                            //         ),
                                            //       );
                                            //       // Optional: Navigate to login
                                            //       return;
                                            //     }

                                            //     final cartItem = CartItemModel(
                                            //       productId: product.id,
                                            //       name: product.name,
                                            //       price: product.price,
                                            //       imageUrl:
                                            //           product.imageUrls.isNotEmpty
                                            //               ? product.imageUrls[0]
                                            //               : '',
                                            //       quantity: 1,
                                            //       brand: product.brand,
                                            //     );

                                            //     context
                                            //         .read<AddToCartCubit>()
                                            //         .addToCart(
                                                      // uid: user.uid,
                                                      // item: cartItem,
                                                      // currentStock:
                                                      //     product.stock,
                                            //         );
                                            //   }
                                            // : null,
