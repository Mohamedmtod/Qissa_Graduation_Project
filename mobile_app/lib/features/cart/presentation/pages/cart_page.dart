import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/custom_empty_state.dart';
import 'package:perfume_app/widgets/home_header_bar.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final ScrollController scrollController = ScrollController();
  bool isAtTop = true;
  @override
  void initState() {
    super.initState();

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
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: true,

        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: isAtTop
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.5),
            ),
          ),
        ),
        automaticallyImplyLeading: false,

        title: HomeHeaderBar(
          color: isAtTop
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          isAtTop: isAtTop,
          radius: 0,
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          if (state is CartStockError) {
            AppSnackBar.showError(
              context,
              resolveUserFacingMessage(
                context,
                state.message,
                fallback: l10n.msgCartUpdateFailed,
              ),
            );
          } else if (state is CartMergeWarning) {
            AppSnackBar.showError(
              context,
              resolveUserFacingMessage(
                context,
                state.message,
                fallback: l10n.msgCartUpdateFailed,
              ),
            );
          }
        },
        child: BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            switch (state) {
              case CartLoading():
                return const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CartSkeleton(),
                  ),
                );
              case CartError():
                return CustomEmptyState(
                  icon: Icons.error_outline,
                  message: resolveUserFacingMessage(
                    context,
                    state.message,
                    fallback: l10n.msgCartUpdateFailed,
                  ),
                  onRetry: () => context.read<CartCubit>().initCart(),
                );
              case CartLoaded():
                if (state.items.isEmpty) {
                  return _buildEmptyCart();
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    ...state.items.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final item = entry.value;
                                      return SizedBox(
                                        child: Column(
                                          children: [
                                            CartCard2(item: item),
                                            if (index != state.items.length - 1)
                                              Divider(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                thickness: 0.5,
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Fixed Total and Checkout
                    CartBottomSection(
                      total: state.total,
                      subtotal: state.subtotal,
                      shipping: state.shipping,
                      discount: state.discount,
                      onCheckout: _checkoutAction(context),
                      scrollController: scrollController,
                    ),
                  ],
                );
              default:
                return _buildEmptyCart();
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    final l10n = AppLocalizations.of(context);
    return CustomEmptyState(
      icon: Icons.shopping_cart_outlined,
      message: l10n.msgEmptyCart,
    );
  }

  VoidCallback _checkoutAction(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      return navigateToCheckout(context);
    }
    return navigateToLoginForCheckout(context);
  }
}

class CartCard extends StatelessWidget {
  final CartItemModel item;
  const CartCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          // Image
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.image,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomTextStyle(
                  text: item.name,
                  maxLines: 2,
                  textOverflow: TextOverflow.ellipsis,
                  fontsize: 14,
                  bold: true,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: 4),
                CustomTextStyle(
                  text: item.brand,
                  fontsize: 14,
                  bold: false,
                  textColor: lightGray,
                ),
                const SizedBox(height: 12),
                CustomTextStyle(
                  text: AppLocalizations.of(
                    context,
                  ).labelPrice(item.price.toString()),
                  fontsize: 16,
                  bold: true,
                  textColor: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
          // Quantity and Remove
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {
                  context.read<CartCubit>().removeFromCart(item.cartDocumentId);
                },
                icon: const Icon(Icons.close, color: lightGray, size: 20),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: () {
                          context.read<CartCubit>().updateQuantity(
                            item.cartDocumentId,
                            item.quantity - 1,
                          );
                        },
                      ),
                      SizedBox(
                        width: 30,
                        child: Center(
                          child: CustomTextStyle(
                            text: '${item.quantity}',
                            fontsize: 16,
                            bold: true,
                            textColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: () {
                          context.read<CartCubit>().updateQuantity(
                            item.cartDocumentId,
                            item.quantity + 1,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CartCard2 extends StatelessWidget {
  final CartItemModel item;
  const CartCard2({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.image,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: item.name,
                            maxLines: 2,
                            textOverflow: TextOverflow.ellipsis,
                            fontsize: 14,
                            bold: true,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            paddingTop: 12,
                          ),
                          CustomTextStyle(
                            text: item.brand,
                            fontsize: 14,
                            bold: false,
                            textColor: lightGray,
                          ),
                        ],
                      ),
                    ),
                    // Remove
                    IconButton(
                      onPressed: () {
                        context.read<CartCubit>().removeFromCart(
                          item.cartDocumentId,
                        );
                      },
                      icon: const Icon(Icons.close, color: lightGray, size: 20),
                    ),
                  ],
                ),

                Spacer(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: CustomTextStyle(
                        text: AppLocalizations.of(
                          context,
                        ).labelPrice(item.price.toString()),
                        fontsize: 16,
                        bold: true,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Quantity and
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: offWhite,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () {
                                context.read<CartCubit>().updateQuantity(
                                  item.cartDocumentId,
                                  item.quantity - 1,
                                );
                              },
                            ),
                            SizedBox(
                              width: 24,
                              child: Center(
                                child: CustomTextStyle(
                                  text: '${item.quantity}',
                                  fontsize: 16,
                                  bold: true,
                                  textColor: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () {
                                context.read<CartCubit>().updateQuantity(
                                  item.cartDocumentId,
                                  item.quantity + 1,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        22,
      ), // matches half of 44 to create a circular splash
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: offWhite,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class CartBottomSection extends StatefulWidget {
  final double total;
  final double subtotal;
  final double shipping;
  final double discount;
  final VoidCallback onCheckout;
  final ScrollController? scrollController;

  const CartBottomSection({
    super.key,
    required this.total,
    required this.subtotal,
    required this.shipping,
    required this.onCheckout,
    required this.discount,
    this.scrollController,
  });

  @override
  State<CartBottomSection> createState() => _CartBottomSectionState();
}

class _CartBottomSectionState extends State<CartBottomSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_isExpanded ? 20 : 0),
          topRight: Radius.circular(_isExpanded ? 20 : 0),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expandable Details
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Column(
                      children: [
                        buildSummaryRow(
                          l10n.labelOrderSummary,
                          '',
                          isHeader: true,
                        ),
                        const SizedBox(height: 10),
                        buildSummaryRow(
                          l10n.labelSubtotal,
                          l10n.labelPrice(widget.subtotal.toStringAsFixed(2)),
                        ),
                        const SizedBox(height: 8),
                        buildSummaryRow(
                          l10n.labelShippingFee,
                          l10n.labelPrice(widget.shipping.toStringAsFixed(2)),
                        ),
                        const SizedBox(height: 8),
                        buildSummaryRow(
                          l10n.labelDiscounts,
                          l10n.labelPrice(widget.discount.toStringAsFixed(2)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Total and Interactable Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _isExpanded = !_isExpanded);
                    if (_isExpanded &&
                        widget.scrollController != null &&
                        widget.scrollController!.hasClients) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (widget.scrollController!.hasClients) {
                          widget.scrollController!.animateTo(
                            widget.scrollController!.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    }
                  },
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelPrice(
                              widget.total.toStringAsFixed(2),
                            ),
                            fontsize: 18,
                            bold: true,
                            textColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: widget.onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: CustomTextStyle(
                      text: l10n.btnCheckout,
                      fontsize: 14,
                      bold: true,
                      textColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSummaryRow(String label, String value, {bool isHeader = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomTextStyle(
          text: label,
          fontsize: isHeader ? 16 : 14,
          bold: isHeader,
          textColor: isHeader
              ? Theme.of(context).colorScheme.onSurface
              : lightGray,
        ),
        if (value.isNotEmpty)
          CustomTextStyle(
            text: value,
            fontsize: 14,
            bold: true,
            textColor: Theme.of(context).colorScheme.onSurface,
          ),
      ],
    );
  }
}
