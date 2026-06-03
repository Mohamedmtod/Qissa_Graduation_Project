import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_state.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class RecommendedProductCard extends StatelessWidget {
  final RecommendedProduct recommendation;
  final int? displayIndex;
  final bool compact;

  const RecommendedProductCard({
    super.key,
    required this.recommendation,
    this.displayIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    final isOutOfStock = product.stock <= 0;
    final compact = this.compact || MediaQuery.sizeOf(context).width < 360;
    final showSaleBadge = product.isOnSale && product.discountPercent != null;

    return BlocBuilder<AIChatCubit, AIChatState>(
      builder: (context, state) {
        final isNotified = state.notifiedProductIds.contains(product.id);
        final l10n = AppLocalizations.of(context);
        final overBudgetPercent = recommendation.overBudgetPercent;
        final overBudgetLabel = overBudgetPercent == null
            ? null
            : (state.language.isArabic
                  ? 'أعلى ${overBudgetPercent.toStringAsFixed(0)}% من الميزانية'
                  : '+${overBudgetPercent.toStringAsFixed(0)}% over budget');
        final matchBadgeLabel = recommendation.matchLabel.trim().isNotEmpty
            ? recommendation.matchLabel.trim()
            : _fallbackMatchBadgeLabel(
                recommendation.matchScore,
                state.language,
              );
        final reasonText = recommendation.matchReason.trim();
        final whyThisPick = _buildWhyThisPickText(
          product,
          reasonText,
          state.language,
        );
        final compactReasonText = reasonText.isNotEmpty
            ? reasonText
            : (state.language.isArabic ? whyThisPick : '');
        final signatureDetail = _buildSignatureDetail(product, state.language);
        final showReasonText = compact && compactReasonText.isNotEmpty;
        final showOverBudget =
            recommendation.budgetStatus ==
                RecommendedBudgetStatus.slightlyAboveBudget &&
            overBudgetLabel != null;
        final showInsights =
            !compact && (whyThisPick.isNotEmpty || signatureDetail.isNotEmpty);

        return GestureDetector(
          key: ValueKey('ai_chat_recommendation_card_${product.id}'),
          onTap: () {
            if (recommendation.budgetStatus ==
                RecommendedBudgetStatus.slightlyAboveBudget) {
              context.read<AIChatCubit>().onUpsellProductTapped(recommendation);
            }
            context.push('/product/${product.id}?source=ai_chat');
          },
          child: SizedBox(
            height: compact ? 390 : 346,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(
                      context: context,
                      product: product,
                      compact: compact,
                      isOutOfStock: isOutOfStock,
                      displayIndex: displayIndex,
                      matchBadgeLabel: matchBadgeLabel,
                      soldOutLabel: l10n.labelSoldOut,
                    ),

                    // Details section
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 5.0 : 14.0),
                        child: _buildDetailsContent(
                          context: context,
                          product: product,
                          compact: compact,
                          showSaleBadge: showSaleBadge,
                          showReasonText: showReasonText,
                          showOverBudget: showOverBudget,
                          showInsights: showInsights,
                          isOutOfStock: isOutOfStock,
                          isNotified: isNotified,
                          reasonText: compactReasonText,
                          overBudgetLabel: overBudgetLabel,
                          whyThisPick: whyThisPick,
                          signatureDetail: signatureDetail,
                          language: state.language,
                          l10n: l10n,
                        ),
                      ),
                    ),
                  ],
                ),
              ), // ClipRRect
            ),
          ),
        );
      },
    );
  }

  String _fallbackMatchBadgeLabel(double score, AIChatLanguage language) {
    if (score >= 0.85) {
      return language.isArabic ? 'تطابق ممتاز' : 'Excellent Match';
    }
    if (score >= 0.70) {
      return language.isArabic ? 'تطابق جيد جدًا' : 'Great Match';
    }
    if (score >= 0.55) {
      return language.isArabic ? 'تطابق جيد' : 'Good Match';
    }
    return language.isArabic ? 'تطابق محدود' : 'Partial Match';
  }

  String _buildSignatureDetail(ProductModel product, AIChatLanguage language) {
    final notes = <String>[
      ...product.topNotes.take(2),
      if (product.topNotes.isEmpty) ...product.notes.take(2),
      ...product.middleNotes.take(1),
      ...product.baseNotes.take(1),
    ].where((note) => note.trim().isNotEmpty).take(4).toList();

    final parts = <String>[
      if (product.fragranceFamily.trim().isNotEmpty)
        product.fragranceFamily.trim(),
      if (product.occasion.trim().isNotEmpty)
        _displayScalar(product.occasion.trim(), language),
      if (product.intensity.trim().isNotEmpty)
        _displayScalar(product.intensity.trim(), language),
    ];

    final notesText = notes.isEmpty
        ? ''
        : language.isArabic
        ? 'أبرز النوتات: ${notes.join('، ')}'
        : 'Signature notes: ${notes.join(', ')}';
    final profileText = parts.isEmpty
        ? ''
        : language.isArabic
        ? 'مناسب لـ ${parts.join('، ')}'
        : 'Best for ${parts.join(', ')}';

    if (notesText.isEmpty) return profileText;
    if (profileText.isEmpty) return notesText;
    return '$notesText. $profileText.';
  }

  String _buildWhyThisPickText(
    ProductModel product,
    String reasonText,
    AIChatLanguage language,
  ) {
    final notes = <String>[
      ...product.topNotes.take(2),
      if (product.topNotes.isEmpty) ...product.notes.take(2),
    ].where((note) => note.trim().isNotEmpty).take(2).toList();

    final profileParts = <String>[
      if (product.fragranceFamily.trim().isNotEmpty)
        product.fragranceFamily.trim(),
      if (product.occasion.trim().isNotEmpty)
        _displayScalar(product.occasion.trim(), language),
      if (product.intensity.trim().isNotEmpty)
        _displayScalar(product.intensity.trim(), language),
    ];

    if (language.isArabic) {
      final pieces = <String>[];
      if (reasonText.isNotEmpty) {
        pieces.add(reasonText);
      }
      if (notes.isNotEmpty) {
        pieces.add('ويميل لنوتات ${notes.join('، ')}.');
      }
      if (profileParts.isNotEmpty) {
        pieces.add('مناسب لـ ${profileParts.join('، ')}.');
      }
      return pieces.join(' ');
    }

    final pieces = <String>[];
    if (reasonText.isNotEmpty) {
      pieces.add(reasonText);
    }
    if (notes.isNotEmpty) {
      pieces.add('It leans into ${notes.join(', ')} notes.');
    }
    if (profileParts.isNotEmpty) {
      pieces.add('Works well for ${profileParts.join(', ')}.');
    }
    return pieces.join(' ');
  }

  String _displayScalar(String value, AIChatLanguage language) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    if (!language.isArabic) return normalized;
    return switch (normalized) {
      'summer' => 'صيفي',
      'winter' => 'شتوي',
      'spring' => 'ربيعي',
      'autumn' => 'خريفي',
      'all seasons' => 'كل الفصول',
      'daily' => 'يومي',
      'university' => 'جامعة',
      'office' => 'للشغل',
      'formal' => 'رسمي',
      'evening' => 'سهرة',
      'date' => 'موعد',
      'casual' => 'كاجوال',
      'day' => 'نهاري',
      'night' => 'ليلي',
      'all day' => 'طوال اليوم',
      'light' => 'هادي',
      'medium' => 'متوسط',
      'strong' => 'قوي',
      'fresh' => 'فريش',
      'clean' => 'نظيف',
      'amber' => 'عنبر',
      'spicy' => 'توابل',
      'citrus' => 'حمضيات',
      'woody' => 'خشبي',
      _ => value,
    };
  }

  Widget _buildImageSection({
    required BuildContext context,
    required ProductModel product,
    required bool compact,
    required bool isOutOfStock,
    required int? displayIndex,
    required String matchBadgeLabel,
    required String soldOutLabel,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(compact ? 12 : 16),
          ),
          child: SizedBox(
            height: compact ? 188 : 178,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: product.imageUrls.isNotEmpty
                  ? product.imageUrls.first
                  : '',
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Match quality badge
        Positioned(
          top: compact ? 6 : 12,
          right: compact ? 6 : 12,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 3 : 6,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest
                  .withValues(alpha: 0.95),
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
              matchBadgeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: compact ? 10 : 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),

        // Out of stock overlay badge
        if (isOutOfStock)
          Positioned(
            top: compact ? 6 : 12,
            left: compact ? 6 : 12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 5 : 8,
                vertical: compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                soldOutLabel,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Display Index Badge (#1, #2, #3)
        if (displayIndex != null)
          Positioned(
            top: compact ? 6 : 12,
            left: isOutOfStock ? (compact ? 50 : 100) : (compact ? 6 : 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 5 : 8,
                vertical: compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "#$displayIndex",
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  fontSize: compact ? 9 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsContent({
    required BuildContext context,
    required ProductModel product,
    required bool compact,
    required bool showSaleBadge,
    required bool showReasonText,
    required bool showOverBudget,
    required bool showInsights,
    required bool isOutOfStock,
    required bool isNotified,
    required String reasonText,
    required String? overBudgetLabel,
    required String whyThisPick,
    required String signatureDetail,
    required AIChatLanguage language,
    required AppLocalizations l10n,
  }) {
    final reasonTextScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.0);
    return Column(
      mainAxisSize: MainAxisSize.max,
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
          style: TextStyle(fontSize: compact ? 10 : 13, color: darkGray),
        ),
        SizedBox(height: compact ? 3 : 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.labelPrice(product.effectivePrice.toStringAsFixed(0)),
                style: TextStyle(
                  fontSize: compact ? 12 : 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (showSaleBadge)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        if (product.isOnSale) SizedBox(height: compact ? 2 : 4),
        if (showReasonText) ...[
          SizedBox(height: compact ? 2 : 6),
          Text(
            language.isArabic ? 'السبب: $reasonText' : 'Why: $reasonText',
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            textScaler: reasonTextScaler,
            style: TextStyle(
              fontSize: compact ? 11 : 15,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: darkGray,
            ),
          ),
        ],
        if (showOverBudget && overBudgetLabel != null) ...[
          SizedBox(height: compact ? 3 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
            ),
            child: Text(
              overBudgetLabel,
              style: TextStyle(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
        if (showInsights) ...[
          SizedBox(height: compact ? 6 : 12),
          _buildInsightsRow(
            compact: compact,
            language: language,
            whyThisPick: whyThisPick,
            signatureDetail: signatureDetail,
          ),
        ],
        const Spacer(),
        // Button
        SizedBox(height: compact ? 4 : 14),
        SizedBox(
          width: double.infinity,
          height: compact ? 30 : 44,
          child: _buildActionButton(
            context: context,
            product: product,
            compact: compact,
            isOutOfStock: isOutOfStock,
            isNotified: isNotified,
            l10n: l10n,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsRow({
    required bool compact,
    required AIChatLanguage language,
    required String whyThisPick,
    required String signatureDetail,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 260;
        final showBoth = whyThisPick.isNotEmpty && signatureDetail.isNotEmpty;

        if (isNarrow) {
          return const SizedBox.shrink();
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (whyThisPick.isNotEmpty)
              Expanded(
                child: _InsightPanel(
                  icon: Icons.auto_awesome,
                  label: language.isArabic ? 'سبب الترشيح' : 'Why this pick',
                  value: whyThisPick,
                  compact: compact,
                ),
              ),
            if (showBoth) const SizedBox(width: 8),
            if (signatureDetail.isNotEmpty)
              Expanded(
                child: _InsightPanel(
                  icon: Icons.spa_outlined,
                  label: language.isArabic
                      ? 'تفاصيل الرائحة'
                      : 'Signature detail',
                  value: signatureDetail,
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required ProductModel product,
    required bool compact,
    required bool isOutOfStock,
    required bool isNotified,
    required AppLocalizations l10n,
  }) {
    return ElevatedButton(
      onPressed: (isOutOfStock && isNotified)
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
                  AppSnackBar.showSuccess(
                    context,
                    l10n.msgNotifyMeRequestSaved,
                  );
                }
              } else {
                context.push('/product/${product.id}?source=ai_chat');
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutOfStock
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : Theme.of(context).colorScheme.primary,
        foregroundColor: isOutOfStock
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(context).colorScheme.surfaceContainerLowest,
        disabledBackgroundColor: Colors.grey.shade100,
        disabledForegroundColor: darkGray,
        elevation: 0,
        padding: compact ? const EdgeInsets.symmetric(horizontal: 8) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          side: (isOutOfStock && !isNotified)
              ? BorderSide(color: Colors.grey.shade300)
              : BorderSide.none,
        ),
      ),
      child: Text(
        isOutOfStock
            ? (isNotified ? l10n.labelNotifySaved : l10n.btnNotifyMe)
            : l10n.btnDetails,
        style: TextStyle(
          fontSize: compact ? 11 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _InsightPanel({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 12 : 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : 6),
          Text(
            value,
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 9.5 : 13,
              color: Theme.of(context).colorScheme.onSurface,
              height: compact ? 1.2 : 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
