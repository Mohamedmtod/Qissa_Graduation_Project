import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/recommendations/presentation/manager/recommended_products_cubit.dart';
import 'package:perfume_app/features/recommendations/presentation/manager/recommended_products_state.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';
import 'package:perfume_app/features/home/presentation/widgets/home_section_header.dart';

class BehavioralRecommendationsSection extends StatefulWidget {
  final String? excludeProductId;

  const BehavioralRecommendationsSection({super.key, this.excludeProductId});

  @override
  State<BehavioralRecommendationsSection> createState() =>
      _BehavioralRecommendationsSectionState();
}

class _BehavioralRecommendationsSectionState
    extends State<BehavioralRecommendationsSection> {
  late final RecommendedProductsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = RecommendedProductsCubit(
      productRepo: context.read<ProductRepo>(),
      userTasteRepo: context.read<UserTasteRepo>(),
    )..load(excludeProductId: widget.excludeProductId);
  }

  @override
  void didUpdateWidget(covariant BehavioralRecommendationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.excludeProductId != widget.excludeProductId) {
      _cubit.load(excludeProductId: widget.excludeProductId);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<RecommendedProductsCubit, RecommendedProductsState>(
        builder: (context, state) {
          if (state.status == RecommendedProductsStatus.loading ||
              state.status == RecommendedProductsStatus.initial) {
            return const _RecommendationsLoadingSkeleton();
          }

          if (state.status == RecommendedProductsStatus.empty ||
              state.status == RecommendedProductsStatus.error ||
              state.products.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeSectionHeader(
                title: _sectionTitle(l10n, state.source),
                padding: const EdgeInsetsDirectional.only(
                  start: 12,
                  end: 12,
                  top: 24,
                  bottom: 12,
                ),
              ),
              SizedBox(
                height: HorizontalProductsSectionStyle.base
                    .scale(0.72)
                    .cardAreaHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.products.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return MainProductsCard(
                      product: state.products[index],
                      scale: 0.72,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _sectionTitle(AppLocalizations l10n, RecommendationSource? source) {
    if (source == RecommendationSource.behavioral) {
      return l10n.labelBehavioralRecommendationsTitle;
    }
    return l10n.labelFallbackRecommendationsTitle;
  }
}

class _RecommendationsLoadingSkeleton extends StatelessWidget {
  const _RecommendationsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 160,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, _) {
              return Container(
                width: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
