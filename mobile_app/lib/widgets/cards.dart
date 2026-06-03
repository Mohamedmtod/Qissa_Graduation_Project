import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/features/cart/data/models/cart_item_model.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/cart/presentation/manager/add_to_cart_cubit.dart';
import 'package:perfume_app/features/categories/data/models/category_model.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/widgets/get_user_info.dart';
import 'package:perfume_app/widgets/notify_me_button.dart';
import 'package:perfume_app/gen/assets.gen.dart';
import 'package:perfume_app/widgets/wishlist_toggle_icon.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class CategorySection extends StatelessWidget {
  final String title;
  final double titleFontSize;
  final double descriptionFontSize;
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double sectionHeight;
  final int itemCount;
  final double photoCardHeight;
  final double photoCardWidth;
  final double cornerRadius;
  final double distanceBetweenCards;

  final List<CategoryModel> icons;
  const CategorySection({
    super.key,
    required this.title,
    required this.titleFontSize,
    this.paddingTop = 0,
    this.paddingBottom = 0,
    this.paddingLeft = 0,

    required this.sectionHeight,
    required this.itemCount,
    required this.photoCardHeight,
    required this.photoCardWidth,
    required this.descriptionFontSize,
    required this.cornerRadius,
    required this.distanceBetweenCards,

    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SliverToBoxAdapter(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Align(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: paddingLeft),
              child: CustomTextStyle(
                text: title,
                fontsize: titleFontSize,
                textColor: Theme.of(context).colorScheme.onSurface,
                bold: true,
                paddingTop: paddingTop,
                paddingBottom: paddingBottom,
              ),
            ),
          ),
          SizedBox(
            height: sectionHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              itemBuilder: (BuildContext context, int index) {
                final category = icons[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(cornerRadius),
                  onTap: () {
                    context.push(
                      Uri(
                        pathSegments: ['', 'category', category.displayName],
                        queryParameters: {
                          if (category.filterValue != category.displayName)
                            'filter': category.filterValue,
                        },
                      ).toString(),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: paddingLeft,
                      right: distanceBetweenCards,
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: photoCardHeight,
                          width: photoCardWidth,
                          decoration: BoxDecoration(
                            color: offWhite,
                            borderRadius: BorderRadius.circular(cornerRadius),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(cornerRadius),
                            child: Container(
                              color: lighterBeige2,
                              child: _buildItemImage(
                                icons[index],
                                width: photoCardWidth,
                                height: photoCardHeight,
                              ),
                            ),
                          ),
                        ),
                        CustomTextStyle(
                          bold: true,
                          fontsize: descriptionFontSize,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          text: category.displayName,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(
    CategoryModel category, {
    required double width,
    required double height,
  }) {
    if (category.imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: category.imageUrl,
        fit: BoxFit.contain,
        memCacheWidth: (width * 3).round(),
        memCacheHeight: (height * 3).round(),
        placeholder: (context, url) =>
            Container(color: lighterBeige2, child: const SizedBox.expand()),
        errorWidget: (context, url, error) => _buildLocalFallback(category),
      );
    }
    return _buildLocalFallback(category);
  }

  Widget _buildLocalFallback(CategoryModel category) {
    final name = category.categoryName.toLowerCase();
    final query = category.query.toLowerCase();

    if (name.contains('perfume') || query.contains('perfume')) {
      return Assets.icons.perfume.image(fit: BoxFit.contain);
    } else if (name.contains('bokhoor') ||
        query.contains('bokhoor') ||
        query.contains('oud')) {
      return Assets.icons.bokhoor.image(fit: BoxFit.contain);
    } else if (name.contains('mabkhara') || query.contains('mabkhara')) {
      return Assets.icons.mabkhara.image(fit: BoxFit.contain);
    } else if (name.contains('fawa') || query.contains('fawa')) {
      return Assets.icons.fawa7aIcon.image(fit: BoxFit.contain);
    } else if (name.contains('watch') || query.contains('watch')) {
      return Assets.icons.watch.image(fit: BoxFit.contain);
    } else if (name.contains('sunglass') || query.contains('sunglass')) {
      return Assets.icons.sunglassIcon.image(fit: BoxFit.contain);
    }

    return const Icon(Icons.category_outlined, color: Colors.grey);
  }
}

class VerticalProductsCard extends StatelessWidget {
  final ScrollController? scrollController;

  final double scale;
  final List<dynamic> products;

  final int itemCount;

  const VerticalProductsCard({
    super.key,
    required this.products,

    required this.scale,

    this.scrollController,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ProductCardStyle.base.scale(scale).verticalCardPadding,
        ),
        child: SizedBox(
          width:
              ProductCardStyle.base.scale(scale).cardWidth * 2 +
              ProductCardStyle.base.scale(scale).horzDistanceBetweenCards,
          child: GridView.builder(
            padding: EdgeInsets.only(
              top: ProductCardStyle.base.scale(scale).verticalCardPadding,
              bottom: 20, // explicitly set bottom padding to reduce extra space
            ),
            controller: scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: ProductCardStyle.base.scale(scale).cardHeight,

              crossAxisSpacing: ProductCardStyle.base
                  .scale(scale)
                  .horzDistanceBetweenCards,
              mainAxisSpacing: ProductCardStyle.base
                  .scale(scale)
                  .verticalCardMainSpacing,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index >= products.length) {
                // Skeleton card at the bottom during pagination
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: ProductCardSkeleton(),
                );
              }
              final product = products[index];
              return MainProductsCard(product: product, scale: scale);
            },
          ),
        ),
      ),
    );
  }
}

class HorizProductsCard extends StatelessWidget {
  final String title;
  final double titleFontSize;
  final double titlePaddingTop;
  final double titlePaddingBottom;
  final double titlePaddingLeft;
  final List<ProductModel> products;
  final double distanceBetweenCards;
  final double scale;
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const HorizProductsCard({
    super.key,
    required this.title,
    required this.titleFontSize,
    this.titlePaddingTop = 0,
    this.titlePaddingBottom = 0,
    this.titlePaddingLeft = 0,

    required this.distanceBetweenCards,

    required this.products,

    required this.scale,
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty && isLoading) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: titlePaddingLeft,
                end: titlePaddingLeft,
              ),
              child: CustomTextStyle(
                text: title,
                fontsize: titleFontSize,
                textColor: Theme.of(context).colorScheme.onSurface,
                bold: true,
                paddingTop: titlePaddingTop,
                paddingBottom: titlePaddingBottom,
              ),
            ),
            HorizontalProductsSkeleton(
              itemCount: 3,
              itemWidth: ProductCardStyle.base.scale(scale).cardWidth,
              itemHeight: HorizontalProductsSectionStyle.base
                  .scale(scale)
                  .cardAreaHeight,
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return PlaceHolderForProCard(
        paddingTop: titlePaddingTop,
        title: title,
        titleFontSize: titleFontSize,
        paddingBottom: titlePaddingBottom,
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Title row — Directionality handles RTL/LTR automatically
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: titlePaddingLeft,
              end: titlePaddingLeft,
            ),
            child: Row(
              children: [
                CustomTextStyle(
                  text: title,
                  fontsize: titleFontSize,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  bold: true,
                  paddingTop: titlePaddingTop,
                  paddingBottom: titlePaddingBottom,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: CustomTextStyle(
                    text: text,
                    fontsize: titleFontSize * 0.6,
                    textColor: AppTheme.primary,
                    bold: true,
                    paddingTop: titlePaddingTop,
                    paddingBottom: titlePaddingBottom,
                  ),
                ),
              ],
            ),
          ),

          // Card
          SizedBox(
            height: HorizontalProductsSectionStyle.base
                .scale(scale)
                .cardAreaHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (BuildContext context, int index) {
                final product = products[index];
                return Row(
                  children: [
                    SizedBox(width: titlePaddingLeft),
                    MainProductsCard(product: product, scale: scale),
                  ],
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return SizedBox(width: distanceBetweenCards);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceHolderForProCard extends StatelessWidget {
  const PlaceHolderForProCard({
    super.key,
    required this.paddingTop,
    required this.title,
    required this.titleFontSize,
    required this.paddingBottom,
    this.message,
  });

  final double paddingTop;
  final String title;
  final double titleFontSize;
  final double paddingBottom;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: paddingTop, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextStyle(
              text: title,
              fontsize: titleFontSize,
              textColor: Theme.of(context).colorScheme.onSurface,
              bold: true,
              paddingTop: paddingTop,
              paddingBottom: paddingBottom,
            ),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: lightBeige.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey,
                      size: 30,
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: isRtl
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: CustomTextStyle(
                        text:
                            message ??
                            AppLocalizations.of(context).labelComingSoon,
                        fontsize: 14,
                        textColor: Colors.grey,
                        bold: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCardImage extends StatelessWidget {
  const _ProductCardImage({
    required this.imageUrl,
    required this.logicalWidth,
    required this.logicalHeight,
  });

  final String imageUrl;
  final double logicalWidth;
  final double logicalHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        color: lightGray,
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: (logicalWidth * devicePixelRatio).round(),
      memCacheHeight: (logicalHeight * devicePixelRatio).round(),
      placeholder: (context, url) =>
          SkeletonWrapper(child: Container(color: Colors.grey[100])),
      errorWidget: (context, url, error) =>
          const Center(child: Icon(Icons.error, color: Colors.red)),
    );
  }
}

class MainProductsCard extends StatelessWidget {
  const MainProductsCard({
    super.key,
    required this.product,

    required this.scale,
  });

  final ProductModel product;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = ProductCardStyle.base.scale(scale);
    final isOutOfStock = product.stock <= 0;
    final bool isFlashSale = product.isOnSale;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      borderRadius: BorderRadius.circular(
        ProductCardStyle.base.scale(scale).cornerRadius,
      ),
      onTap: () {
        GoRouter.of(context).push('/product/${product.id}');
      },
      child: SizedBox(
        height: ProductCardStyle.base.scale(scale).cardHeight,
        child: ClipRRect(
          child: Stack(
            children: [
              Container(
                height: ProductCardStyle.base.scale(scale).cardHeight,
                width: ProductCardStyle.base.scale(scale).cardWidth,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(
                    ProductCardStyle.base.scale(scale).cornerRadius,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        height: ProductCardStyle.base.scale(scale).imageHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              ProductCardStyle.base.scale(scale).cornerRadius,
                            ),
                            topRight: Radius.circular(
                              ProductCardStyle.base.scale(scale).cornerRadius,
                            ),
                          ),
                          child: _ProductCardImage(
                            imageUrl: product.imageUrls.isNotEmpty
                                ? product.imageUrls.first
                                : '',
                            logicalWidth: style.cardWidth,
                            logicalHeight: style.imageHeight,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(
                            ProductCardStyle.base.scale(scale).cornerRadius,
                          ),
                          bottomRight: Radius.circular(
                            ProductCardStyle.base.scale(scale).cornerRadius,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .09),
                            blurRadius: 4,
                            spreadRadius: -4,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: style.contentPaddingLeft,
                          top: style.contentPaddingTop,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextStyle(
                              bold: true,
                              semiBold: true,
                              fontsize: style.productNameFontSize,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              text: product.name,

                              maxLines: 1,
                              textOverflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: style.nameBrandGap),

                            CustomTextStyle(
                              bold: false,
                              semiBold: true,
                              fontsize: style.productBrandFontSize,
                              textColor: AppTheme.outline,
                              text: product.brand,
                              maxLines: 1,
                              textOverflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: (product.isOnSale
                                  ? style.brandPriceGap / 2
                                  : style.brandPriceGap),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: CustomTextStyle(
                                    text: AppLocalizations.of(context)
                                        .labelPrice(
                                          product.defaultVariant.effectivePrice
                                              .toStringAsFixed(0),
                                        ),
                                    fontsize: style.priceFontSize,
                                    textColor: AppTheme.secondary,
                                    bold: true,
                                    maxLines: 1,
                                    textOverflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (product.isOnSale)
                              Row(
                                children: [
                                  CustomTextStyle(
                                    text: AppLocalizations.of(context)
                                        .labelPrice(
                                          product.defaultVariant.price
                                              .toStringAsFixed(0),
                                        ),
                                    fontsize:
                                        style.productBrandFontSize -
                                        style.originalPriceFontSizeAdjustment,
                                    textColor: AppTheme.outline,
                                    bold: false,
                                    maxLines: 1,
                                    textOverflow: TextOverflow.ellipsis,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  SizedBox(width: 4),
                                  if (product.discountPercent != null)
                                    CustomTextStyle(
                                      text: '-${product.discountPercent}%',
                                      fontsize: style.discountBadgeFontSize,
                                      textColor: Color(0xff13b331),
                                      bold: true,

                                      maxLines: 1,
                                      textOverflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // wishlist icon
              Positioned(
                top: style.wishListIconPosTop,
                right: isRtl ? null : style.wishListIconPosRight,
                left: isRtl ? style.wishListIconPosRight : null,
                child: WishlistToggleIcon(
                  product: product,
                  size: style.wishListIconSize,
                  backgroundSize: style.wishListIconBackgroundSize,
                ),
              ),

              if (isOutOfStock ||
                  product.isBestSeller ||
                  product.isNew ||
                  isFlashSale)
                Positioned(
                  top: ProductCardStyle.base.scale(scale).wishListIconPosTop,
                  left: isRtl
                      ? null
                      : ProductCardStyle.base.scale(scale).wishListIconPosRight,
                  right: isRtl
                      ? ProductCardStyle.base.scale(scale).wishListIconPosRight
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.isBestSeller)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                style.soldOutBadgePaddingHorizontal *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            vertical:
                                style.soldOutBadgePaddingVertical *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xff0c4e4a),
                            borderRadius: BorderRadius.circular(
                              style.soldOutBadgeBorderRadius,
                            ),
                          ),
                          child: CustomTextStyle(
                            text: AppLocalizations.of(context).labelBestSeller,
                            fontsize:
                                style.soldOutBadgeFontSize *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            textColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            bold: true,
                          ),
                        ),
                      if (product.isNew)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                style.soldOutBadgePaddingHorizontal *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            vertical:
                                style.soldOutBadgePaddingVertical *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xff005c97), // New Badge Color
                            borderRadius: BorderRadius.circular(
                              style.soldOutBadgeBorderRadius,
                            ),
                          ),
                          child: CustomTextStyle(
                            text: AppLocalizations.of(context).labelNew,
                            fontsize:
                                style.soldOutBadgeFontSize *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            textColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            bold: true,
                          ),
                        ),
                      if (isFlashSale)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                style.soldOutBadgePaddingHorizontal *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            vertical:
                                style.soldOutBadgePaddingVertical *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(
                              style.soldOutBadgeBorderRadius,
                            ),
                          ),
                          child: CustomTextStyle(
                            text: AppLocalizations.of(context).labelFlashSale,
                            fontsize:
                                style.soldOutBadgeFontSize *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            textColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            bold: true,
                          ),
                        ),
                      if (isOutOfStock)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                style.soldOutBadgePaddingHorizontal *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            vertical:
                                style.soldOutBadgePaddingVertical *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                          ),
                          decoration: BoxDecoration(
                            color: red.withValues(
                              alpha: style.soldOutBadgeAlpha,
                            ),
                            borderRadius: BorderRadius.circular(
                              style.soldOutBadgeBorderRadius,
                            ),
                          ),
                          child: CustomTextStyle(
                            text: AppLocalizations.of(context).labelSoldOut,
                            fontsize:
                                style.soldOutBadgeFontSize *
                                scale.clamp(
                                  style.soldOutBadgeScaleMin,
                                  style.soldOutBadgeScaleMax,
                                ),
                            textColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            bold: true,
                          ),
                        ),
                    ],
                  ),
                ),

              // add to cart icon
              Positioned(
                bottom: ProductCardStyle.base
                    .scale(scale)
                    .addToCartIconPosBottom,
                right: isRtl
                    ? null
                    : ProductCardStyle.base.scale(scale).addToCartIconPosRight,
                left: isRtl
                    ? ProductCardStyle.base.scale(scale).addToCartIconPosRight
                    : null,
                child: isOutOfStock
                    ? NotifyMeButton(
                        productId: product.id,
                        height: style.addToCartButtonHeight,
                        width: style.addToCartButtonWidth,
                        compact: scale < style.compactScaleThreshold,
                        borderRadius: style.cornerRadius,
                      )
                    : AddtoCartButton(
                        builder: (context, data) {
                          return _MainCardCartControl(
                            product: product,
                            scale: scale,
                            isLoading: data.isLoading,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainCardCartControl extends StatelessWidget {
  const _MainCardCartControl({
    required this.product,
    required this.scale,
    required this.isLoading,
  });

  final ProductModel product;
  final double scale;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    CartCubit? cartCubit;
    try {
      cartCubit = context.read<CartCubit>();
    } catch (_) {
      cartCubit = null;
    }

    final activeCartCubit = cartCubit;
    if (activeCartCubit == null) {
      return _buildInitialAddButton(context);
    }

    return BlocSelector<CartCubit, CartState, CartItemModel?>(
      bloc: activeCartCubit,
      selector: (state) {
        if (state is CartLoaded) {
          for (final item in state.items) {
            if (item.productId == product.id) {
              return item;
            }
          }
        }
        return null;
      },
      builder: (context, currentItem) {
        if (currentItem == null) {
          return _buildInitialAddButton(context);
        }

        return _buildQuantityControl(context, activeCartCubit, currentItem);
      },
    );
  }

  Widget _buildInitialAddButton(BuildContext context) {
    final style = ProductCardStyle.base.scale(scale);
    final canAdd = product.defaultVariant.stock > 0 && !isLoading;

    return Container(
      height: style.addToCartButtonHeight,
      width: style.addToCartButtonWidth,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(style.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: style.buttonShadowAlpha),
            offset: Offset(0, style.buttonShadowOffsetVertical),
            blurRadius: style.buttonShadowBlurRadius,
          ),
        ],
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: style.addToCartIconSize * style.loadingIndicatorScale,
                height: style.addToCartIconSize * style.loadingIndicatorScale,
                child: CircularProgressIndicator(
                  strokeWidth: style.loadingIndicatorStrokeWidth,
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
              )
            : IconButton(
                icon: const Icon(Icons.add),
                padding: EdgeInsets.zero,
                iconSize: style.addToCartIconSize,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                onPressed: canAdd ? () => _handleFirstAdd(context) : null,
              ),
      ),
    );
  }

  Widget _buildQuantityControl(
    BuildContext context,
    CartCubit cartCubit,
    CartItemModel item,
  ) {
    final style = ProductCardStyle.base.scale(scale);
    final quantity = item.quantity;
    final variantStock = product.defaultVariant.stock;
    final bool canIncrease = variantStock > 0 && !isLoading;

    return Container(
      height: style.addToCartButtonHeight,
      width: style.addToCartButtonWidth * style.quantityControlWidthFactor,
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(style.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: style.buttonShadowAlpha),
            offset: Offset(0, style.buttonShadowOffsetVertical),
            blurRadius: style.buttonShadowBlurRadius,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: IconButton(
              onPressed: () {
                if (quantity <= 1) {
                  cartCubit.removeFromCart(item.cartDocumentId);
                  return;
                }
                cartCubit.updateQuantity(item.cartDocumentId, quantity - 1);
              },
              icon: Icon(
                quantity <= 1 ? Icons.delete : Icons.remove,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                size: style.addToCartIconSize * style.quantityControlIconScale,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: Center(
              child: CustomTextStyle(
                text: quantity.toString(),
                fontsize: style.priceFontSize * style.quantityControlTextScale,
                textColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                bold: true,
              ),
            ),
          ),
          Expanded(
            child: IconButton(
              onPressed: canIncrease
                  ? () {
                      if (quantity >= variantStock) {
                        final l10n = AppLocalizations.of(context);
                        AppSnackBar.showError(
                          context,
                          l10n.msgOnlyItemsAvailable(variantStock),
                        );
                        return;
                      }

                      cartCubit.updateQuantity(
                        item.cartDocumentId,
                        quantity + 1,
                      );
                    }
                  : null,
              icon: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                size: style.addToCartIconSize * style.quantityControlIconScale,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _handleFirstAdd(BuildContext context) {
    final user = _currentAuthUser(context);

    final cartItem = CartItemModel(
      productId: product.id,
      variantId: product.defaultVariant.id,
      variantLabel:
          product.defaultVariant.label == ProductVariantModel.defaultVariantId
          ? ''
          : product.defaultVariant.label,
      name: product.name,
      price: product.defaultVariant.effectivePrice,
      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
      quantity: 1,
      brand: product.brand,
      notes: product.notes,
    );

    context.read<AddToCartCubit>().addToCart(
      uid: user?.uid ?? CartRepo.guestCartUserId,
      item: cartItem,
      currentStock: product.defaultVariant.stock,
    );
  }

  dynamic _currentAuthUser(BuildContext context) {
    try {
      return context.read<AuthBloc>().state.user;
    } catch (_) {
      return null;
    }
  }
}

class ProductCardStyle {
  final double cardWidth;
  final double cardHeight;
  final double cornerRadius;
  final double imageHeight;
  final double sliderPosition;
  final double selectedSliderWidth;
  final double defaultSliderWidth;
  final double priceFontSize;
  final double wishListIconSize;
  final double addToCartButtonHeight;
  final double addToCartButtonWidth;
  final double addToCartIconSize;
  final double addToCartIconPosBottom;
  final double addToCartIconPosRight;
  final double wishListIconPosTop;
  final double wishListIconPosRight;
  final double productNameFontSize;
  final double productBrandFontSize;
  final double contentPaddingLeft;
  final double contentPaddingTop;
  final double nameBrandGap;
  final double brandPriceGap;
  final double cardShadowBlur;
  final double wishListIconBackgroundSize;
  final double horzDistanceBetweenCards;
  final double quantityControlWidthFactor;
  final double quantityControlIconScale;
  final double quantityControlTextScale;
  final double discountBadgeMarginStart;
  final double discountBadgePaddingHorizontal;
  final double discountBadgePaddingVertical;
  final double discountBadgeBorderRadius;
  final double discountBadgeFontSize;
  final double productSizePaddingBottom;
  final double productSizeFontSizeAdjustment;
  final double originalPriceFontSizeAdjustment;
  final double soldOutBadgePaddingHorizontal;
  final double soldOutBadgePaddingVertical;
  final double soldOutBadgeBorderRadius;
  final double soldOutBadgeFontSize;
  final double soldOutBadgeScaleMin;
  final double soldOutBadgeScaleMax;
  final double notifyMeButtonWidthFactor;
  final double loadingIndicatorScale;
  final double loadingIndicatorStrokeWidth;
  final double buttonShadowOffsetVertical;
  final double buttonShadowBlurRadius;
  final double compactScaleThreshold;
  final double discountBadgeAlpha;
  final double buttonShadowAlpha;
  final double soldOutBadgeAlpha;
  final double verticalCardMainSpacing;
  final double verticalCardPadding;

  const ProductCardStyle({
    required this.cardWidth,
    required this.cardHeight,
    required this.cornerRadius,
    required this.imageHeight,
    required this.sliderPosition,
    required this.selectedSliderWidth,
    required this.defaultSliderWidth,
    required this.priceFontSize,
    required this.wishListIconSize,
    required this.addToCartButtonHeight,
    required this.addToCartButtonWidth,
    required this.addToCartIconSize,
    required this.addToCartIconPosBottom,
    required this.addToCartIconPosRight,
    required this.wishListIconPosTop,
    required this.wishListIconPosRight,
    required this.productNameFontSize,
    required this.productBrandFontSize,
    required this.contentPaddingLeft,
    required this.contentPaddingTop,
    required this.nameBrandGap,
    required this.brandPriceGap,
    required this.cardShadowBlur,
    required this.wishListIconBackgroundSize,
    required this.horzDistanceBetweenCards,
    required this.quantityControlWidthFactor,
    required this.quantityControlIconScale,
    required this.quantityControlTextScale,
    required this.discountBadgeMarginStart,
    required this.discountBadgePaddingHorizontal,
    required this.discountBadgePaddingVertical,
    required this.discountBadgeBorderRadius,
    required this.discountBadgeFontSize,
    required this.productSizePaddingBottom,
    required this.productSizeFontSizeAdjustment,
    required this.originalPriceFontSizeAdjustment,
    required this.soldOutBadgePaddingHorizontal,
    required this.soldOutBadgePaddingVertical,
    required this.soldOutBadgeBorderRadius,
    required this.soldOutBadgeFontSize,
    required this.soldOutBadgeScaleMin,
    required this.soldOutBadgeScaleMax,
    required this.notifyMeButtonWidthFactor,
    required this.loadingIndicatorScale,
    required this.loadingIndicatorStrokeWidth,
    required this.buttonShadowOffsetVertical,
    required this.buttonShadowBlurRadius,
    required this.compactScaleThreshold,
    required this.discountBadgeAlpha,
    required this.buttonShadowAlpha,
    required this.soldOutBadgeAlpha,
    required this.verticalCardMainSpacing,
    required this.verticalCardPadding,
  });

  static const base = ProductCardStyle(
    cardHeight: 425,
    cardWidth: 260,

    cornerRadius: 40,
    imageHeight: 270,
    sliderPosition: 5,
    selectedSliderWidth: 16,
    defaultSliderWidth: 8,

    priceFontSize: 20,
    wishListIconSize: 26,

    addToCartButtonHeight: 48,
    addToCartButtonWidth: 80,
    addToCartIconSize: 30,
    addToCartIconPosBottom: 20,
    addToCartIconPosRight: 20,

    wishListIconPosTop: 20,
    wishListIconPosRight: 20,

    productNameFontSize: 21,
    productBrandFontSize: 16,

    contentPaddingLeft: 12,
    contentPaddingTop: 12,
    nameBrandGap: 4,
    brandPriceGap: 20,
    cardShadowBlur: 4,
    wishListIconBackgroundSize: 10,
    horzDistanceBetweenCards: 20,
    quantityControlWidthFactor: 1.5,
    quantityControlIconScale: 0.7,
    quantityControlTextScale: 0.7,

    discountBadgeMarginStart: 10,
    discountBadgePaddingHorizontal: 12,
    discountBadgePaddingVertical: 4,
    discountBadgeBorderRadius: 8,
    discountBadgeFontSize: 16,

    productSizePaddingBottom: 4,
    productSizeFontSizeAdjustment: 1,
    originalPriceFontSizeAdjustment: 1,

    soldOutBadgePaddingHorizontal: 10,
    soldOutBadgePaddingVertical: 6,
    soldOutBadgeBorderRadius: 8,
    soldOutBadgeFontSize: 16,
    soldOutBadgeScaleMin: 0.75,
    soldOutBadgeScaleMax: 1.0,

    notifyMeButtonWidthFactor: 1.8,

    loadingIndicatorScale: 0.65,
    loadingIndicatorStrokeWidth: 2,

    buttonShadowOffsetVertical: 2,
    buttonShadowBlurRadius: 6,

    compactScaleThreshold: 0.85,
    discountBadgeAlpha: 0.1,
    buttonShadowAlpha: 0.06,
    soldOutBadgeAlpha: 0.9,
    verticalCardMainSpacing: 15,
    verticalCardPadding: 12,
  );
}

class HorizontalProductsSectionStyle {
  final double titleFontSize;
  final double titlePaddingTop;
  final double titlePaddingBottom;
  final double titlePaddingLeft;
  final double cardPaddingLeft;
  final double distanceBetweenCards;
  final double cardAreaHeight;

  const HorizontalProductsSectionStyle({
    required this.titleFontSize,
    required this.titlePaddingTop,
    required this.titlePaddingBottom,
    required this.titlePaddingLeft,
    required this.cardPaddingLeft,
    required this.distanceBetweenCards,
    required this.cardAreaHeight,
  });

  static const base = HorizontalProductsSectionStyle(
    titleFontSize: 22,
    titlePaddingTop: 24,
    titlePaddingBottom: 12,
    titlePaddingLeft: 0,
    cardPaddingLeft: 0,
    distanceBetweenCards: 50,
    cardAreaHeight: 425,
  );
}

extension ProductCardStyleScale on ProductCardStyle {
  ProductCardStyle scale(double s) {
    return ProductCardStyle(
      cardWidth: cardWidth * s,
      cardHeight: cardHeight * s,
      cornerRadius: cornerRadius * s,
      imageHeight: imageHeight * s,
      sliderPosition: sliderPosition * s,
      selectedSliderWidth: selectedSliderWidth * s,
      defaultSliderWidth: defaultSliderWidth * s,
      priceFontSize: priceFontSize * s,
      wishListIconSize: wishListIconSize * s,
      addToCartButtonHeight: addToCartButtonHeight * s,
      addToCartButtonWidth: addToCartButtonWidth * s,
      addToCartIconSize: addToCartIconSize * s,
      addToCartIconPosBottom: addToCartIconPosBottom * s,
      addToCartIconPosRight: addToCartIconPosRight * s,
      wishListIconPosTop: wishListIconPosTop * s,
      wishListIconPosRight: wishListIconPosRight * s,
      productNameFontSize: productNameFontSize * s,
      productBrandFontSize: productBrandFontSize * s,
      contentPaddingLeft: contentPaddingLeft * s,
      contentPaddingTop: contentPaddingTop * s,
      nameBrandGap: nameBrandGap * s,
      brandPriceGap: brandPriceGap * s,
      cardShadowBlur: cardShadowBlur * s,
      wishListIconBackgroundSize: wishListIconBackgroundSize * s,
      horzDistanceBetweenCards: horzDistanceBetweenCards * s,
      quantityControlWidthFactor: quantityControlWidthFactor,
      quantityControlIconScale: quantityControlIconScale,
      quantityControlTextScale: quantityControlTextScale,
      discountBadgeMarginStart: discountBadgeMarginStart * s,
      discountBadgePaddingHorizontal: discountBadgePaddingHorizontal * s,
      discountBadgePaddingVertical: discountBadgePaddingVertical * s,
      discountBadgeBorderRadius: discountBadgeBorderRadius * s,
      discountBadgeFontSize: discountBadgeFontSize * s,
      productSizePaddingBottom: productSizePaddingBottom * s,
      productSizeFontSizeAdjustment: productSizeFontSizeAdjustment * s,
      originalPriceFontSizeAdjustment: originalPriceFontSizeAdjustment * s,
      soldOutBadgePaddingHorizontal: soldOutBadgePaddingHorizontal * s,
      soldOutBadgePaddingVertical: soldOutBadgePaddingVertical * s,
      soldOutBadgeBorderRadius: soldOutBadgeBorderRadius * s,
      soldOutBadgeFontSize: soldOutBadgeFontSize * s,
      soldOutBadgeScaleMin: soldOutBadgeScaleMin,
      soldOutBadgeScaleMax: soldOutBadgeScaleMax,
      notifyMeButtonWidthFactor: notifyMeButtonWidthFactor,
      loadingIndicatorScale: loadingIndicatorScale,
      loadingIndicatorStrokeWidth: loadingIndicatorStrokeWidth,
      buttonShadowOffsetVertical: buttonShadowOffsetVertical * s,
      buttonShadowBlurRadius: buttonShadowBlurRadius * s,
      compactScaleThreshold: compactScaleThreshold,
      discountBadgeAlpha: discountBadgeAlpha,
      buttonShadowAlpha: buttonShadowAlpha,
      soldOutBadgeAlpha: soldOutBadgeAlpha,
      verticalCardMainSpacing: verticalCardMainSpacing * s,
      verticalCardPadding: verticalCardPadding * s,
    );
  }
}

extension HorizontalProductsSectionStyleScale
    on HorizontalProductsSectionStyle {
  HorizontalProductsSectionStyle scale(double s) {
    return HorizontalProductsSectionStyle(
      titleFontSize: titleFontSize * s,
      titlePaddingTop: titlePaddingTop * s,
      titlePaddingBottom: titlePaddingBottom * s,
      titlePaddingLeft: titlePaddingLeft * s,
      cardPaddingLeft: cardPaddingLeft * s,
      distanceBetweenCards: distanceBetweenCards * s,
      cardAreaHeight: cardAreaHeight * s,
    );
  }
}
