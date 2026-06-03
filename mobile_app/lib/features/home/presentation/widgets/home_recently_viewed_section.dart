import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/presentation/manager/recently_viewed_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class HomeRecentlyViewedSection extends StatelessWidget {
  const HomeRecentlyViewedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<RecentlyViewedCubit, RecentlyViewedState>(
      builder: (context, recentlyViewedState) {
        final viewedProducts = recentlyViewedState is RecentlyViewedSuccess
            ? recentlyViewedState.products
            : <ProductModel>[];
        final isLoading = recentlyViewedState is RecentlyViewedLoading;

        if (recentlyViewedState is RecentlyViewedSuccess &&
            viewedProducts.isNotEmpty) {
          debugPrint(
            '🎄 HomePage: Recently Viewed section loaded with ${viewedProducts.length} products',
          );
        } else if (recentlyViewedState is RecentlyViewedSuccess &&
            viewedProducts.isEmpty) {
          debugPrint(
            '📭 HomePage: No recently viewed products yet',
          );
        }

        if (viewedProducts.isEmpty && !isLoading) {
          return PlaceHolderForProCard(
            paddingTop: 24,
            title: l10n.labelViewedBefore,
            titleFontSize: 22,
            paddingBottom: 12,
            message: l10n.msgNoRecentlyViewedProducts,
          );
        }

        if (isLoading) {
          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 12,
                    top: 24,
                    bottom: 12,
                  ),
                  child: CustomTextStyle(
                    text: l10n.labelViewedBefore,
                    fontsize: 22,
                    textColor: Theme.of(context).colorScheme.onSurface,
                    bold: true,
                  ),
                ),
                HorizontalProductsSkeleton(
                  itemCount: 3,
                  itemWidth: ProductCardStyle.base.scale(0.7).cardWidth,
                  itemHeight: HorizontalProductsSectionStyle.base
                      .scale(0.7)
                      .cardAreaHeight,
                ),
              ],
            ),
          );
        }

        return HorizProductsCard(
          title: l10n.labelViewedBefore,
          titleFontSize: 22,
          titlePaddingTop: 24,
          titlePaddingBottom: 12,
          titlePaddingLeft: 12,
          distanceBetweenCards: 6,
          products: viewedProducts,
          scale: 0.7,
          text: l10n.btnHistory,
          onTap: () {
            context.push('/category/viewed-before');
          },
        );
      },
    );
  }
}
