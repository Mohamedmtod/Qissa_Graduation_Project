import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/widgets/cards.dart';
import 'package:perfume_app/widgets/custom_empty_state.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: CustomTextStyle(
          text: l10n.labelMyWishlist,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
      ),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, state) {
          if (state is WishlistLoading) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: ProductGridSkeleton(crossAxisCount: 2, itemCount: 10),
            );
          } else if (state is WishlistError) {
            return CustomEmptyState(
              icon: Icons.error_outline,
              message: resolveUserFacingMessage(
                context,
                state.message,
                fallback: l10n.msgWishlistLoadFailed,
              ),
            );
          } else if (state is WishlistLoaded) {
            if (state.items.isEmpty || state.products.isEmpty) {
              return CustomEmptyState(
                icon: Icons.favorite_border,
                message: l10n.msgEmptyWishlist,
              );
            }

            return VerticalProductsCard(
              itemCount: state.products.length,
              products: state.products,

              scale: .7,
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
