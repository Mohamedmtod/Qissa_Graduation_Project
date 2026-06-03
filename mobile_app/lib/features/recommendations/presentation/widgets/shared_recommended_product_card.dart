import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class SharedRecommendedProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryAction;
  final String primaryActionLabel;
  final bool primaryActionEnabled;
  final bool compact;
  final String? topRightBadge;
  final String? topLeftBadge;
  final String? supportingText;

  const SharedRecommendedProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionEnabled = true,
    this.compact = false,
    this.topRightBadge,
    this.topLeftBadge,
    this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(compact ? 12 : 16),
                  ),
                  child: AspectRatio(
                    aspectRatio: compact ? 1.3 : 1.5,
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (topRightBadge != null)
                  Positioned(
                    top: compact ? 6 : 12,
                    right: compact ? 6 : 12,
                    child: _Badge(
                      text: topRightBadge!,
                      compact: compact,
                      background: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest
                          .withValues(alpha: 0.95),
                      foreground: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (topLeftBadge != null)
                  Positioned(
                    top: compact ? 6 : 12,
                    left: compact ? 6 : 12,
                    child: _Badge(
                      text: topLeftBadge!,
                      compact: compact,
                      background: Colors.red.withValues(alpha: 0.9),
                      foreground: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: compact ? 1 : 2),
                  Text(
                    product.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 13,
                      color: darkGray,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.labelPrice(
                            product.effectivePrice.toStringAsFixed(0),
                          ),
                          style: TextStyle(
                            fontSize: compact ? 12 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      if (product.isOnSale && product.discountPercent != null)
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
                            '-${product.discountPercent}%',
                            style: TextStyle(
                              fontSize: compact ? 8 : 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (product.isOnSale)
                    Text(
                      l10n.labelPrice(product.price.toStringAsFixed(0)),
                      style: TextStyle(
                        fontSize: compact ? 9 : 12,
                        color: darkGray,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (supportingText != null &&
                      supportingText!.trim().isNotEmpty) ...[
                    SizedBox(height: compact ? 6 : 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 8 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        supportingText!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: compact ? 14 : 16,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 6 : 14),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 32 : 44,
                    child: ElevatedButton(
                      onPressed: primaryActionEnabled
                          ? (onPrimaryAction ?? onTap)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        disabledBackgroundColor: Colors.grey.shade100,
                        disabledForegroundColor: darkGray,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(compact ? 8 : 12),
                        ),
                      ),
                      child: Text(
                        primaryActionLabel,
                        style: TextStyle(
                          fontSize: compact ? 11 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool compact;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.text,
    required this.compact,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: compact ? 10 : 12,
          color: foreground,
        ),
      ),
    );
  }
}
