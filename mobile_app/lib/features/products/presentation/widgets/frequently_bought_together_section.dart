import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/products/data/models/frequent_recommendation_model.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/frequent_recommendation_repo.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

class FrequentlyBoughtTogetherSection extends StatefulWidget {
  final String productId;

  const FrequentlyBoughtTogetherSection({
    super.key,
    required this.productId,
  });

  @override
  State<FrequentlyBoughtTogetherSection> createState() =>
      _FrequentlyBoughtTogetherSectionState();
}

class _FrequentlyBoughtTogetherSectionState
    extends State<FrequentlyBoughtTogetherSection> {
  late Future<List<_RecommendedProductViewData>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant FrequentlyBoughtTogetherSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _future = _loadRecommendations();
    }
  }

  Future<List<_RecommendedProductViewData>> _loadRecommendations() async {
    final recommendationRepo = context.read<FrequentRecommendationRepo>();
    final productRepo = context.read<ProductRepo>();

    final recommendation =
        await recommendationRepo.fetchByTriggerProductId(widget.productId);
    if (recommendation == null || recommendation.recommendedProducts.isEmpty) {
      return const [];
    }

    final topRules = recommendation.recommendedProducts.take(3).toList();
    final products = await productRepo.fetchProductsByIds(
      topRules.map((item) => item.productId).toList(),
    );

    final productsById = {
      for (final product in products) product.id: product,
    };

    return topRules
        .map((rule) {
          final product = productsById[rule.productId];
          if (product == null) return null;
          return _RecommendedProductViewData(product: product, rule: rule);
        })
        .whereType<_RecommendedProductViewData>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RecommendedProductViewData>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FrequentlyBoughtTogetherSkeleton();
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        
        final l10n = AppLocalizations.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 24),
            CustomTextStyle(
              text: l10n.labelFrequentlyBoughtTogether,
              fontsize: 18,
              textColor: Theme.of(context).colorScheme.onSurface,
              bold: true,
              paddingBottom: 6,
            ),
            Text(
              l10n.msgCustomersAlsoBought,
              style: const TextStyle(
                fontSize: 12,
                color: darkGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 310,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _RecommendedProductCard(item: item);
                },
              ),
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }
}

class _FrequentlyBoughtTogetherSkeleton extends StatelessWidget {
  const _FrequentlyBoughtTogetherSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 28),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Column(
          key: const Key('fbt_loading_skeleton'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 24),
            Container(
              width: 220,
              height: 18,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 280,
              height: 12,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 310,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) => Container(
                  width: 158,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 156,
                        decoration: BoxDecoration(
                          color: offWhite,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 62,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 108,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 94,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 80,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedProductCard extends StatelessWidget {
  final _RecommendedProductViewData item;

  const _RecommendedProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imageUrl =
        item.product.imageUrls.isNotEmpty ? item.product.imageUrls.first : '';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/product/${item.product.id}?source=fbt'),
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lighterBeige2),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 156,
                color: offWhite,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.inventory_2_outlined, color: darkGray)
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.product.brand.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: lightGray,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  l10n.labelPrice(item.product.effectivePrice.toStringAsFixed(0)),
                  style: const TextStyle(
                    fontSize: 16,
                    color: gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.product.isOnSale && item.product.discountPercent != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '-${item.product.discountPercent}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
            if (item.product.isOnSale)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  l10n.labelPrice(item.product.price.toStringAsFixed(0)),
                  style: const TextStyle(
                    fontSize: 12,
                    color: darkGray,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedProductViewData {
  final ProductModel product;
  final RecommendedProductRule rule;

  const _RecommendedProductViewData({
    required this.product,
    required this.rule,
  });
}
