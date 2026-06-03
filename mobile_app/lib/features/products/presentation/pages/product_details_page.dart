import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_state.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/add_to_cart_cubit.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/widgets/product_image_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/features/products/presentation/widgets/frequently_bought_together_section.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/behavioral_recommendations_section.dart';
import 'package:perfume_app/features/products/presentation/widgets/product_details_shimmer.dart';
import 'package:perfume_app/widgets/custom_error_widget.dart';
import 'package:perfume_app/widgets/get_user_info.dart';
import 'package:perfume_app/widgets/full_screen_image_viewer.dart';
import 'package:perfume_app/widgets/nav_bar.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final String? source;
  const ProductDetailsPage({super.key, required this.productId, this.source});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final ScrollController _controller = ScrollController();
  late final PageController _bgController;
  late final PageController _fgController;
  String? _selectedVariantId;

  static const double _imageH = 350; // Height of the image area
  static const double _overlap =
      -10; // How much the details sheet overlaps the image area

  @override
  void initState() {
    super.initState();
    _bgController = PageController();
    _fgController = PageController();

    // Sync foreground swipes to background visual slider
    _fgController.addListener(() {
      if (_bgController.hasClients && _fgController.hasClients) {
        _bgController.jumpTo(_fgController.position.pixels);
      }
    });


  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
    _fgController.dispose();
    super.dispose();
  }

  ProductVariantModel _selectedVariantFor(ProductModel product) {
    final selectedId = _selectedVariantId;
    if (selectedId != null) {
      for (final variant in product.variants) {
        if (variant.id == selectedId) return variant;
      }
    }
    return product.defaultVariant;
  }

  Widget _buildVariantSelector(ProductModel product) {
    if (product.variants.length <= 1) {
      final label = product.defaultVariant.label;
      if (label.trim().isEmpty ||
          label == ProductVariantModel.defaultVariantId) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    final selectedVariant = _selectedVariantFor(product);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: product.variants.map((variant) {
          final isSelected = variant.id == selectedVariant.id;
          final isDisabled = variant.stock <= 0;
          return ChoiceChip(
            label: Text(
              variant.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            selected: isSelected,
            onSelected: isDisabled
                ? null
                : (_) {
                    setState(() => _selectedVariantId = variant.id);
                  },
            selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            disabledColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              color: isDisabled
                  ? Colors.grey
                  : isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double appBarH = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
        builder: (context, state) {
          if (state is ProductDetailsLoading) {
            return const ProductDetailsShimmer();
          }
          if (state is ProductDetailsError) {
            return CustomErrorWidget(
              message: resolveUserFacingMessage(
                context,
                state.message,
                fallback: l10n.msgProductLoadFailed,
              ),
              onRetry: () {
                context.read<ProductDetailsCubit>().watchProduct(
                  widget.productId,
                );
              },
            );
          }
          if (state is ProductDetailsUnavailable) {
            final product = state.product;
            return _UnavailableProductScreen(
              productName: product.name,
              onBackToMainLayout: () {
                context.read<LayoutCubit>().changeIndex(Go.home);
                context.go('/MainLayout');
              },
            );
          }
          if (state is! ProductDetailsSuccess) return const SizedBox();

          final product = state.product;
          final selectedVariant = _selectedVariantFor(product);
          final isSelectedVariantOnSale = selectedVariant.isOnSale;
          final selectedVariantDiscountPercent =
              isSelectedVariantOnSale && selectedVariant.price > 0
              ? ((selectedVariant.price - selectedVariant.salePrice!) /
                        selectedVariant.price *
                        100)
                    .round()
              : null;

          return Stack(
            children: [
              // ===== 1. Background Image Layer (Visual Bottom) =====
              Positioned(
                top: 0, // Starts below the pinned app bar
                left: 0,
                right: 0,
                height: _imageH + appBarH,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final offset = _controller.hasClients ? _controller.offset : 0.0;
                    final t = (offset / _imageH).clamp(0.0, 1.0);
                    final scale = 1.08 - (0.08 * t);
                    final translateY = -(offset * 0.35);

                    return Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: ProductImageSlider(
                    imageUrls: product.imageUrls,
                    height: _imageH,

                    sliderPositionVertically: 60,
                    selectedSliderWidth: 24,
                    defaultSliderWidth: 8,
                    boxFit: BoxFit.contain,
                    controller: _bgController,
                    physics: const NeverScrollableScrollPhysics(),
                  ),
                ),
              ),

              // ===== 2. Foreground Scroll Layer (Details Sheet) =====
              Positioned.fill(
                child: CustomScrollView(
                  controller: _controller,
                  slivers: [
                    // Transparent Spacer & Gesture Capturer
                    // Pushes the details sheet down to reveal the image
                    // AND captures horizontal swipes for the slider
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: appBarH + _imageH - _overlap - 35,
                        child: PageView.builder(
                          controller: _fgController, // Captures gestures
                          itemCount: product.imageUrls.length,
                          itemBuilder: (context, index) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) {
                                        return FullScreenImageViewer(
                                          imageUrls: product.imageUrls,
                                          initialIndex: index,
                                        );
                                      },
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            child: const SizedBox(), // Transparent touch target
                          ),
                        ),
                      ),
                    ),

                    // The Details Sheet
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: Container(
                          // No margin -> Edge-to-edge sheet
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            // border: Border.all(
                            //   color: beige,
                            //   width: 2,
                            // ),
                            // Subtle shadow to separate from image slightly if needed,
                            // but usually flat white sheet is enough.
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTextStyle(
                                  text: product.brand.toUpperCase(),
                                  fontsize: 14,
                                  textColor: lightGray,
                                  bold: true,
                                  paddingBottom: 8,
                                ),
                                CustomTextStyle(
                                  text: product.name,
                                  fontsize: 24,
                                  textColor: Theme.of(context).colorScheme.onSurface,
                                  bold: true,
                                  paddingBottom: 16,
                                ),

                                _buildVariantSelector(product),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: CustomTextStyle(
                                                  text: l10n.labelPrice(
                                                    selectedVariant
                                                        .effectivePrice
                                                        .toStringAsFixed(0),
                                                  ),
                                                  fontsize: 22,
                                                  textColor: gold,
                                                  bold: true,
                                                ),
                                              ),
                                              if (selectedVariantDiscountPercent !=
                                                  null)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '-$selectedVariantDiscountPercent%',
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (isSelectedVariantOnSale)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                l10n.labelPrice(
                                                  selectedVariant.price
                                                      .toStringAsFixed(0),
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selectedVariant.stock > 0
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        selectedVariant.stock > 0
                                            ? l10n.labelInStock
                                            : l10n.labelOutOfStock,
                                        style: TextStyle(
                                          color: selectedVariant.stock > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),
                                const Divider(height: 1),
                                const SizedBox(height: 24),

                                CustomTextStyle(
                                  text: l10n.labelDescription,
                                  fontsize: 18,
                                  textColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  bold: true,
                                  paddingBottom: 12,
                                ),
                                Text(
                                  product.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                BehavioralRecommendationsSection(
                                  excludeProductId: product.id,
                                ),
                                const SizedBox(height: 30),
                                FrequentlyBoughtTogetherSection(
                                  productId: product.id,
                                ),

                                const SizedBox(height: 500), // Bottom padding
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ===== 3. Pinned App Bar Layer (Visual Top) =====
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: appBarH,
                  color: Colors.transparent, // Make background transparent
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: GoBackIcon(
                            navigateTo: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProductBottomActionSection(
                  product: product,
                  selectedVariant: selectedVariant,
                  source: widget.source,
                  scrollController: _controller,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SharedNavBar(currentIndex: Go.home),
    );
  }
}

class _ProductBottomActionSection extends StatefulWidget {
  final ProductModel product;
  final ProductVariantModel selectedVariant;
  final String? source;
  final ScrollController scrollController;

  const _ProductBottomActionSection({
    required this.product,
    required this.selectedVariant,
    required this.source,
    required this.scrollController,
  });

  @override
  State<_ProductBottomActionSection> createState() => _ProductBottomActionSectionState();
}

class _ProductBottomActionSectionState extends State<_ProductBottomActionSection> {
  bool _isQtyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _isQtyExpanded ? Colors.white : Theme.of(context).colorScheme.surface,
        borderRadius: _isQtyExpanded ? const BorderRadius.vertical(top: Radius.circular(20)) : null,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: BlocBuilder<CartCubit, CartState>(
          builder: (context, cartState) {
            CartItemModel? cartItem;
            if (cartState is CartLoaded) {
              try {
                cartItem = cartState.items.firstWhere(
                  (item) => item.productId == widget.product.id && item.variantId == widget.selectedVariant.id,
                );
              } catch (_) {}
            }

            // Ensure it collapses if the item is no longer in the cart
            if (cartItem == null && _isQtyExpanded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isQtyExpanded = false);
              });
            }

            final int maxStock = widget.selectedVariant.stock;
            final limit = maxStock.clamp(1, 10);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _isQtyExpanded && cartItem != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CustomTextStyle(
                                    text: l10n.labelQty,
                                    fontsize: 16,
                                    bold: true,
                                    textColor: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isQtyExpanded = false;
                                      });
                                    },
                                    child: const Icon(Icons.close, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 50,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: limit,
                                itemBuilder: (context, index) {
                                  final number = index + 1;
                                  final isSelected = number == cartItem!.quantity;
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(end: 12),
                                    child: InkWell(
                                      onTap: () {
                                        context.read<CartCubit>().updateQuantity(cartItem!.cartDocumentId, number);
                                        setState(() {
                                          _isQtyExpanded = false;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 50,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.primaryContainer : offWhite,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: CustomTextStyle(
                                            text: '$number',
                                            fontsize: 18,
                                            bold: isSelected,
                                            textColor: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLowest
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.read<CartCubit>().removeFromCart(cartItem!.cartDocumentId);
                                  setState(() => _isQtyExpanded = false);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(
                                  l10n.btnRemoveFromCart,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  height: 65, // Add to cart height is exactly 65
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cartItem != null) ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isQtyExpanded = !_isQtyExpanded;
                            });
                            if (_isQtyExpanded) {
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (widget.scrollController.hasClients) {
                                  final maxScroll = widget.scrollController.position.maxScrollExtent;
                                  final currentScroll = widget.scrollController.offset;
                                  widget.scrollController.animateTo(
                                    (currentScroll + 120).clamp(0, maxScroll),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 65,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomTextStyle(
                                  text: l10n.labelQty,
                                  fontsize: 10,
                                  textColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLowest
                                      .withValues(alpha: 0.7),
                                  bold: true,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 4),
                                    CustomTextStyle(
                                      text: cartItem.quantity.toString(),
                                      fontsize: 16,
                                      textColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest,
                                      bold: true,
                                    ),
                                    Icon(
                                      _isQtyExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: AddtoCartButton(
                          builder: (context, data) {
                            return ElevatedButton(
                              onPressed:
                                  (widget.selectedVariant.stock > 0 && !data.isLoading)
                                  ? () {
                                      final user = FirebaseAuth.instance.currentUser;

                                      final newCartItem = CartItemModel(
                                        productId: widget.product.id,
                                        variantId: widget.selectedVariant.id,
                                        variantLabel: widget.selectedVariant.label == ProductVariantModel.defaultVariantId
                                            ? ''
                                            : widget.selectedVariant.label,
                                        name: widget.product.name,
                                        price: widget.selectedVariant.effectivePrice,
                                        imageUrl: widget.product.imageUrls.isNotEmpty ? widget.product.imageUrls[0] : '',
                                        quantity: 1,
                                        brand: widget.product.brand,
                                        notes: widget.product.notes,
                                        source: widget.source,
                                      );

                                      context.read<AddToCartCubit>().addToCart(
                                        uid: user?.uid ?? CartRepo.guestCartUserId,
                                        item: newCartItem,
                                        currentStock: widget.selectedVariant.stock,
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLowest,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: data.isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLowest,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.selectedVariant.stock > 0
                                          ? l10n.btnAddToCart
                                          : l10n.labelOutOfStock,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UnavailableProductScreen extends StatelessWidget {
  const _UnavailableProductScreen({
    required this.productName,
    required this.onBackToMainLayout,
  });

  final String productName;
  final VoidCallback onBackToMainLayout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 72,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.msgProductUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: lightGray),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBackToMainLayout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(l10n.btnBrowseProducts),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
