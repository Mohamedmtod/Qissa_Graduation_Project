import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/models/shipping_zone_model.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/orders/data/models/address_model.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/orders/presentation/cubit/shipping/shipping_zones_cubit.dart';
import 'package:perfume_app/features/orders/presentation/manager/order_cubit.dart';
import 'package:perfume_app/features/orders/presentation/pages/address_page.dart';
import 'package:perfume_app/features/orders/presentation/utils/shipping_zone_display.dart';
import 'package:perfume_app/gen/assets.gen.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/custom_empty_state.dart';
import 'package:perfume_app/widgets/get_user_info.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    this.referralSource = 'app',
    this.restockRequestId,
  });

  final String referralSource;
  final String? restockRequestId;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic>? _selectedAddress;
  final ScrollController scrollController = ScrollController();
  bool isAtTop = true;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      // Load/Update just in case
      context.read<AddressCubit>().loadDefaultAddress();
    }

    scrollController.addListener(() {
      if (!mounted) return;
      final atTop = scrollController.offset <= 0;

      // عشان نقلل setState على الفاضي
      if (atTop != isAtTop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => isAtTop = atTop);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color gray = Color.fromARGB(255, 236, 234, 234);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: .1),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: navigateToCart(context),
        ),
        title: CustomTextStyle(
          text: AppLocalizations.of(context).labelCheckout,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
        titleSpacing: 0,

        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,

        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              color: isAtTop
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<CartCubit, CartState>(
        buildWhen: (previous, current) {
          final orderState = context.read<OrderCubit>().state;
          // Prevent the screen from clearing out its content
          // while waiting for navigation after success.
          return orderState is! OrderRequestCreated;
        },
        builder: (context, cartState) {
          final authState = context.watch<AuthBloc>().state;
          if (authState.status != AuthStatus.authenticated ||
              authState.user == null) {
            return CustomEmptyState(
              icon: Icons.lock_outline,
              message: AppLocalizations.of(context).msgPleaseLogInFirst,
              actionLabel: AppLocalizations.of(context).btnLogin,
              actionIcon: Icons.login,
              onRetry: navigateToLoginForCheckout(context),
            );
          }

          if (cartState is CartLoading) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CheckoutSkeleton(),
              ),
            );
          }

          if (cartState is! CartLoaded) {
            return CustomEmptyState(
              icon: Icons.shopping_cart_outlined,
              message: AppLocalizations.of(context).msgFailedToLoadCart,
            );
          }

          final cartItems = cartState.items;
          final subtotal = cartState.subtotal;
          final numOfItems = cartItems.length;
          final discount = cartState.discount;
          final locale = Localizations.localeOf(context);

          // ── Resolve shipping fee dynamically from the selected address zone ──
          // CartState.shipping is no longer the source of truth for the final fee.
          final String? selectedZoneCode =
              _selectedAddress?['shippingZoneCode'] as String?;
          final zonesState = context.watch<ShippingZonesCubit>().state;
          ShippingZoneModel? resolvedZone;
          if (zonesState is ShippingZonesLoaded) {
            if (selectedZoneCode != null && selectedZoneCode.isNotEmpty) {
              // Primary: match by stable code (new addresses).
              try {
                resolvedZone = zonesState.zones.firstWhere(
                  (z) => z.code == selectedZoneCode,
                );
              } catch (_) {}
            }

            // Fallback: legacy addresses saved before shippingZoneCode existed.
            // Try to match by city / governorate display name.
            if (resolvedZone == null && _selectedAddress != null) {
              final candidates = <String>[
                _selectedAddress?['city'] as String? ?? '',
                _selectedAddress?['governorate'] as String? ?? '',
                _selectedAddress?['area'] as String? ?? '',
              ].where((s) => s.trim().isNotEmpty).toList();

              for (final candidate in candidates) {
                try {
                  resolvedZone = zonesState.zones.firstWhere(
                    (z) => z.enabled && z.matchesCityName(candidate),
                  );
                  break;
                } catch (_) {}
              }
            }
          }
          final availableZones = zonesState is ShippingZonesLoaded
              ? zonesState.zones
              : const <ShippingZoneModel>[];
          final selectedAddressGovernorate = localizedShippingZoneLabel(
            locale: locale,
            zones: availableZones,
            shippingZoneCode: _selectedAddress?['shippingZoneCode'] as String?,
            governorateCode: _selectedAddress?['governorateCode'] as String?,
            fallbackLabel: _selectedAddress?['governorate'] as String?,
          );
          final selectedAddressCity = localizedShippingZoneLabel(
            locale: locale,
            zones: availableZones,
            shippingZoneCode:
                _selectedAddress?['cityCode'] as String? ??
                _selectedAddress?['shippingZoneCode'] as String?,
            fallbackLabel: [
              _selectedAddress?['city'] as String? ?? '',
              _selectedAddress?['area'] as String? ?? '',
            ].where((part) => part.trim().isNotEmpty).join(', '),
          );
          final double shippingFee = resolvedZone?.fee ?? 0.0;
          final bool zoneIsUnavailable =
              _selectedAddress == null ||
              resolvedZone == null ||
              !resolvedZone.enabled;
          final double total = (subtotal + shippingFee - discount)
              .clamp(0, double.infinity)
              .toDouble();

          return MultiBlocListener(
            listeners: [
              BlocListener<OrderCubit, OrderState>(
                listener: (context, state) async {
                  if (state is OrderRequestCreated) {
                    String successUri({bool cartCleanupFailed = false}) {
                      return Uri(
                        path: '/order-success',
                        queryParameters: {
                          'orderId': state.orderId,
                          if (state.orderCode != null &&
                              state.orderCode!.trim().isNotEmpty)
                            'orderCode': state.orderCode!.trim(),
                          if (cartCleanupFailed) 'cartCleanupFailed': 'true',
                        },
                      ).toString();
                    }

                    try {
                      // Attempt to clear the cart
                      await context.read<CartCubit>().clearCart();

                      if (!context.mounted) return;
                      // Navigate with success
                      context.go(successUri());
                    } catch (e) {
                      debugPrint('Cart clear error: $e');
                      if (!context.mounted) return;

                      // Navigate to success page but pass cartCleanupFailed=true
                      context.go(successUri(cartCleanupFailed: true));
                    }
                  } else if (state is OrderError) {
                    final l10n = AppLocalizations.of(context);
                    AppSnackBar.showError(
                      context,
                      resolveUserFacingMessage(
                        context,
                        state.message,
                        fallback: l10n.msgOrderPlaceFailed,
                      ),
                    );
                  }
                },
              ),
            ],
            child: GetUserAddress(
              onAddressChanged: (address) {
                _selectedAddress = address?.toMap();
              },
              builder: (context, address) {
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(10),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: CustomContainer(
                                  width: double.infinity,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLowest,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CustomTextStyle(
                                        bold: true,
                                        fontsize: 16,
                                        textColor: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        text: AppLocalizations.of(
                                          context,
                                        ).labelAddress,
                                        paddingLeft: 16,
                                        paddingTop: 10,
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () async {
                                            final result =
                                                await openAddressSheetPage(
                                                  context,
                                                );
                                            if (result != null) {
                                              if (context.mounted) {
                                                GetUserAddress.setAddress(
                                                  context,
                                                  AddressModel.fromMap(
                                                    result,
                                                    result['id'] ?? '',
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: CustomContainer(
                                            padding: const EdgeInsets.only(
                                              left: 16,
                                              top: 10,
                                              right: 16,
                                            ),
                                            width: double.infinity,
                                            height: 55,
                                            color: gray,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 40,
                                                  child: Lottie.asset(
                                                    Assets
                                                        .animations
                                                        .locationAnimation,
                                                    repeat: true,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      CustomTextStyle(
                                                        bold: true,
                                                        fontsize: 14,
                                                        textColor: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                        text: address == null
                                                            ? AppLocalizations.of(
                                                                context,
                                                              ).msgSelectDeliveryAddress
                                                            : AppLocalizations.of(
                                                                context,
                                                              ).labelCityStreet(
                                                                selectedAddressCity,
                                                                address.street ??
                                                                    '',
                                                              ),
                                                        maxLines: 1,
                                                      ),
                                                      if (address != null)
                                                        CustomTextStyle(
                                                          bold: false,
                                                          fontsize: 14,
                                                          textColor: darkGray,
                                                          text:
                                                              AppLocalizations.of(
                                                                context,
                                                              ).labelBuildingFloor(
                                                                address.building ??
                                                                    '',
                                                                address.floor ??
                                                                    '',
                                                              ),
                                                          maxLines: 1,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildOrderNotes(),
                              const SizedBox(height: 12),
                              _buildOrderPreview(cartItems),
                              const SizedBox(height: 12),
                              CustomContainer(
                                width: double.infinity,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextStyle(
                                      text: AppLocalizations.of(
                                        context,
                                      ).labelPayWith,
                                      fontsize: 18,
                                      bold: true,
                                      textColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      paddingTop: 10,
                                      paddingLeft: 16,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildPaymentOption(
                                      title: AppLocalizations.of(
                                        context,
                                      ).labelCashOnDelivery,
                                      icon: Icons.payments_outlined,
                                      isSelected: true,
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              CustomContainer(
                                width: double.infinity,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextStyle(
                                      text: AppLocalizations.of(
                                        context,
                                      ).labelPaymentSummary,
                                      fontsize: 18,
                                      bold: true,
                                      textColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      paddingTop: 10,
                                      paddingLeft: 12,
                                    ),
                                    const SizedBox(height: 16),
                                    SummaryRow(
                                      title: AppLocalizations.of(
                                        context,
                                      ).labelSubtotal,
                                      value: subtotal,
                                    ),
                                    SummaryRow(
                                      title: AppLocalizations.of(
                                        context,
                                      ).labelShippingFee,
                                      value: shippingFee,
                                    ),
                                    SummaryRow(
                                      title: AppLocalizations.of(
                                        context,
                                      ).labelDiscounts,
                                      value: discount,
                                    ),
                                    Divider(
                                      color: Colors.grey[300],
                                      thickness: 1,
                                      height: 30,
                                      indent: 12,
                                      endIndent: 12,
                                    ),
                                    SummaryRow(
                                      title: AppLocalizations.of(
                                        context,
                                      ).labelTotal,
                                      value: total,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    BlocBuilder<OrderCubit, OrderState>(
                      builder: (context, state) {
                        return Container(
                          width: double.infinity,
                          height: 125,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed:
                                        (state is OrderLoading ||
                                            state is OrderRequestCreated)
                                        ? null
                                        : () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              final user = context
                                                  .read<AuthBloc>()
                                                  .state
                                                  .user;
                                              if (user == null) {
                                                navigateToLoginForCheckout(
                                                  context,
                                                )();
                                                return;
                                              }
                                              if (_selectedAddress == null) {
                                                AppSnackBar.showError(
                                                  context,
                                                  AppLocalizations.of(
                                                    context,
                                                  ).msgPleaseSelectDeliveryAddress,
                                                );
                                                return;
                                              }

                                              // ── Zone availability check ──
                                              if (zoneIsUnavailable) {
                                                AppSnackBar.showError(
                                                  context,
                                                  AppLocalizations.of(
                                                    context,
                                                  ).msgDeliveryZoneUnavailable,
                                                );
                                                return;
                                              }

                                              final String formattedAddress =
                                                  AppLocalizations.of(
                                                    context,
                                                  ).labelFullAddressDetails(
                                                    (_selectedAddress!['city']
                                                            as String?) ??
                                                        '',
                                                    [
                                                          _selectedAddress!['governorate'],
                                                          _selectedAddress!['area'],
                                                        ]
                                                        .whereType<String>()
                                                        .where(
                                                          (part) => part
                                                              .trim()
                                                              .isNotEmpty,
                                                        )
                                                        .join(', '),
                                                    (_selectedAddress!['street']
                                                            as String?) ??
                                                        '',
                                                    (_selectedAddress!['building']
                                                            as String?) ??
                                                        '',
                                                    (_selectedAddress!['floor']
                                                            as String?) ??
                                                        '',
                                                  );
                                              final String userPhone =
                                                  _selectedAddress!['phone'] ??
                                                  _phoneController.text.trim();

                                              context
                                                  .read<OrderCubit>()
                                                  .placeOrder(
                                                    userId: user.uid,
                                                    cartItems: cartItems,
                                                    total: total,
                                                    address: formattedAddress,
                                                    phone: userPhone,
                                                    paymentMethod:
                                                        PaymentMethodCodes
                                                            .cashOnDelivery,
                                                    referralSource:
                                                        widget.referralSource,
                                                    restockRequestId:
                                                        widget.restockRequestId,
                                                    shippingZoneCode:
                                                        resolvedZone?.code ??
                                                        selectedZoneCode,
                                                    shippingGovernorate:
                                                        selectedAddressGovernorate,
                                                    clientShippingFee:
                                                        shippingFee,
                                                    notes:
                                                        _notesController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : _notesController.text
                                                              .trim(),
                                                  );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 5,
                                    ),
                                    child:
                                        (state is OrderLoading ||
                                            state is OrderRequestCreated)
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : CustomTextStyle(
                                            text: AppLocalizations.of(
                                              context,
                                            ).btnPlaceOrder,
                                            fontsize: 16,
                                            bold: true,
                                            textColor: white,
                                          ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 25.0),
                                child: Row(
                                  children: [
                                    CustomTextStyle(
                                      text: AppLocalizations.of(
                                        context,
                                      ).msgNumOfItems(numOfItems),
                                      fontsize: 16,
                                      bold: false,
                                      textColor: Colors.grey,
                                      paddingLeft: 12,
                                    ),
                                    const Spacer(),
                                    CustomTextStyle(
                                      text: AppLocalizations.of(
                                        context,
                                      ).labelPrice(total.toStringAsFixed(2)),
                                      fontsize: 18,
                                      bold: true,
                                      textColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      paddingRight: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : darkGray,
                size: 22,
              ),
              const SizedBox(width: 12),
              CustomTextStyle(
                text: title,
                fontsize: 15,
                bold: isSelected,
                textColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderPreview(List<dynamic> items) {
    return CustomContainer(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextStyle(
            text: AppLocalizations.of(context).labelOrderPreview,
            fontsize: 16,
            bold: true,
            textColor: Theme.of(context).colorScheme.onSurface,
            paddingTop: 10,
            paddingLeft: 16,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(
                          item.imageUrl,
                          width: 80,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).labelQuantityFormat(item.quantity),
                              style: const TextStyle(
                                color: white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOrderNotes() {
    return CustomContainer(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextStyle(
            text: AppLocalizations.of(context).labelDeliveryInstructions,
            fontsize: 18,
            bold: true,
            textColor: Theme.of(context).colorScheme.onSurface,
            paddingTop: 10,
            paddingLeft: 16,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _notesController,
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(
                  context,
                ).hintAddDeliveryInstructions,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String title;
  final double value;

  const SummaryRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomTextStyle(
          text: title,
          fontsize: 16,
          bold: false,
          textColor: Colors.grey,
          paddingLeft: 12,
        ),
        CustomTextStyle(
          text: AppLocalizations.of(
            context,
          ).labelPrice(value.toStringAsFixed(2)),
          fontsize: 18,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
          paddingRight: 12,
        ),
      ],
    );
  }
}

class CustomContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double width;
  final double? height;
  final EdgeInsets padding;
  const CustomContainer({
    super.key,
    required this.child,
    required this.color,
    required this.width,
    this.height,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
