import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/shared_recommended_product_card.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class AIChatRecommendedProductCardAdapter extends StatelessWidget {
  final RecommendedProduct recommendation;
  final int? displayIndex;
  final bool compact;

  const AIChatRecommendedProductCardAdapter({
    super.key,
    required this.recommendation,
    this.displayIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    final isOutOfStock = product.stock <= 0;

    return BlocBuilder<AIChatCubit, AIChatState>(
      builder: (context, state) {
        final isNotified = state.notifiedProductIds.contains(product.id);
        final l10n = AppLocalizations.of(context);
        final overBudgetPercent = recommendation.overBudgetPercent;
        final overBudgetLabel = overBudgetPercent == null
            ? null
            : (state.language.isArabic
                  ? '\u0623\u0639\u0644\u0649 ${overBudgetPercent.toStringAsFixed(0)}% \u0645\u0646 \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629'
                  : '+${overBudgetPercent.toStringAsFixed(0)}% over budget');

        final topRightBadge = '${(recommendation.matchScore * 100).toInt()}%';
        final topLeftBadge = isOutOfStock
            ? (displayIndex != null
                  ? '#$displayIndex - ${l10n.labelSoldOut}'
                  : l10n.labelSoldOut)
            : (displayIndex != null ? '#$displayIndex' : null);

        final reasonText = recommendation.matchReason.trim();
        final signatureDetail = _buildSignatureDetail(product, state.language);
        final supporting = <String>[
          if (reasonText.isNotEmpty)
            state.language.isArabic
                ? 'سبب الترشيح: $reasonText'
                : 'Why this pick: $reasonText',
          if (signatureDetail.isNotEmpty)
            state.language.isArabic
                ? 'تفصيلة مميزة: $signatureDetail'
                : 'Signature detail: $signatureDetail',
          if (recommendation.budgetStatus ==
                  RecommendedBudgetStatus.slightlyAboveBudget &&
              overBudgetLabel != null)
            overBudgetLabel,
        ].where((line) => line.trim().isNotEmpty).join('\n');

        return SharedRecommendedProductCard(
          product: product,
          compact: compact,
          topRightBadge: topRightBadge,
          topLeftBadge: topLeftBadge,
          supportingText: compact ? null : supporting,
          onTap: () {
            context.read<AIChatCubit>().onRecommendedProductTapped(product);
            if (recommendation.budgetStatus ==
                RecommendedBudgetStatus.slightlyAboveBudget) {
              context.read<AIChatCubit>().onUpsellProductTapped(recommendation);
            }
            context.push('/product/${product.id}?source=ai_chat');
          },
          onPrimaryAction: (isOutOfStock && isNotified)
              ? null
              : () async {
                  if (isOutOfStock) {
                    final userId = context.read<AuthBloc>().state.user?.uid;
                    if (userId == null) {
                      AppSnackBar.showWarning(context, l10n.msgNeedAccountToTrack);
                      return;
                    }

                    await context.read<AIChatCubit>().onNotifyMeRequested(
                      product.id,
                      userId,
                    );
                    if (context.mounted) {
                      AppSnackBar.showWarning(
                        context,
                        l10n.msgNotifyMeRequestSaved,
                      );
                    }
                  } else {
                    context.read<AIChatCubit>().onRecommendedProductTapped(
                      product,
                    );
                    context.push('/product/${product.id}?source=ai_chat');
                  }
                },
          primaryActionEnabled: !(isOutOfStock && isNotified),
          primaryActionLabel: isOutOfStock
              ? (isNotified ? l10n.labelNotifySaved : l10n.btnNotifyMe)
              : l10n.btnDetails,
        );
      },
    );
  }

  String _buildSignatureDetail(ProductModel product, AIChatLanguage language) {
    final notes = <String>[
      ...product.topNotes.take(2),
      if (product.topNotes.isEmpty) ...product.notes.take(2),
    ].where((note) => note.trim().isNotEmpty).take(2).toList();

    if (notes.isNotEmpty) {
      return language.isArabic
          ? 'أبرز النوتات: ${notes.join('، ')}'
          : 'Signature notes: ${notes.join(', ')}';
    }

    final parts = <String>[
      if (product.fragranceFamily.trim().isNotEmpty)
        product.fragranceFamily.trim(),
      if (product.occasion.trim().isNotEmpty) product.occasion.trim(),
      if (product.intensity.trim().isNotEmpty) product.intensity.trim(),
    ];

    if (parts.isEmpty) return '';

    return language.isArabic
        ? 'طابعه ${parts.join('، ')}'
        : 'Profile: ${parts.join(', ')}';
  }
}
