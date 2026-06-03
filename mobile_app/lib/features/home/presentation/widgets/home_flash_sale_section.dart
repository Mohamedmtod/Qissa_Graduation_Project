import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';

class HomeFlashSaleSection extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoading;

  const HomeFlashSaleSection({
    super.key,
    required this.products,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return HorizProductsCard(
      title: l10n.labelFlashSale,
      titleFontSize: 22,
      titlePaddingTop: 24,
      titlePaddingBottom: 12,
      titlePaddingLeft: 12,
      distanceBetweenCards: 12,
      products: products,
      isLoading: isLoading,
      scale: 0.7,
      text: l10n.btnSeeAll,
      onTap: () {
        final title = Uri.encodeComponent(l10n.labelFlashSale);
        context.push('/category/$title?filter=flash-sale');
      },
    );
  }
}
