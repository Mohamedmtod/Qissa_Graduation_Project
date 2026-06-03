import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/wishlist/data/models/wishlist_item_model.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class WishlistToggleIcon extends StatelessWidget {
  final ProductModel product;
  final double size;
  final Color? color;
  final double backgroundSize ;

  const WishlistToggleIcon({
    super.key,
    required this.product,
    this.size = 24,
    this.color,
    required this.backgroundSize ,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WishlistCubit, WishlistState>(
      builder: (context, state) {
        final isWishlisted = context.read<WishlistCubit>().isWishlisted(product.id);
        
        return GestureDetector(
          onTap: () {
            final user = context.read<AuthBloc>().state.user;
            if (user == null) {
              AppSnackBar.showWarning(
                context,
                AppLocalizations.of(context).msgLoginToAddToWishlist,
              );
              return;
            }

            context.read<WishlistCubit>().toggleWishlist(
                  WishlistItemModel(
                    productId: product.id,
                    name: product.name,
                    price: product.effectivePrice,
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
                    brand: product.brand,
                  ),
                );
          },
          child: Container(
            padding:  EdgeInsets.all(backgroundSize),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest
                  .withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: isWishlisted ? AppTheme.primaryContainer : (color ?? Theme.of(context).colorScheme.onSurface),
              size: size,
            ),
          ),
        );
      },
    );
  }
}
