import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/features/home/presentation/manager/home_cubit.dart';
import 'package:perfume_app/features/home/presentation/manager/home_state.dart';
import 'package:perfume_app/features/recommendations/presentation/widgets/behavioral_recommendations_section.dart';
import 'package:perfume_app/features/home/presentation/widgets/home_categories_section.dart';
import 'package:perfume_app/features/home/presentation/widgets/home_flash_sale_section.dart';
import 'package:perfume_app/features/home/presentation/widgets/home_recently_viewed_section.dart';
import 'package:perfume_app/widgets/auto_banner.dart';
import 'package:perfume_app/widgets/home_header_bar.dart';
import 'package:perfume_app/widgets/search_field.dart';
import 'package:perfume_app/widgets/skeletons.dart';

const Key homeBehavioralRecommendationsSectionKey = ValueKey<String>(
  'homeBehavioralRecommendationsSection',
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController scrollController = ScrollController();
  bool isAtTop = true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      if (!mounted) return;
      final atTop = scrollController.offset <= 0;
      if (atTop != isAtTop) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => isAtTop = atTop);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double pad = 12;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 600,
            child: BlocBuilder<HomeCubit, HomeState>(
              builder: (context, state) {
                if (state is HomeLoading) {
                  return const SafeArea(child: HomeSkeleton());
                } else if (state is HomeError) {
                  return Center(
                    child: Text(
                      resolveUserFacingMessage(
                        context,
                        state.message,
                        fallback: l10n.msgHomeLoadFailed,
                      ),
                    ),
                  );
                } else if (state is HomeSuccess) {
                  return SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            controller: scrollController,
                            slivers: [
                              SliverToBoxAdapter(
                                child: HomeHeaderBar(
                                  color: Theme.of(context).colorScheme.surface,
                                  isAtTop: isAtTop,
                                  padding: EdgeInsetsDirectional.only(
                                    start: pad,
                                    end: pad,
                                  ),
                                ),
                              ),
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: SearchHeaderDelegate(
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 80,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        padding: EdgeInsetsDirectional.only(
                                          start: pad,
                                          end: pad,
                                        ),
                                        child: SearchField(
                                          hintText: l10n.hintSearch,
                                          maxLength: 30,
                                          height: 60,
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                            top: 5,
                                          ),
                                          fontSize: 16,
                                          fillColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLowest,
                                          readOnly: true,
                                          borderRadius: 50,
                                          onTap: () {
                                            GoRouter.of(
                                              context,
                                            ).push('/search');
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: AutoBanner(
                                  height: 225,
                                  padding: EdgeInsetsDirectional.only(
                                    start: pad,
                                    end: pad,
                                  ),
                                  banners: state.banners.map((bannerInfo) {
                                    return BannerWidget(
                                      bannerInfo: bannerInfo,
                                      padding: EdgeInsetsDirectional.only(
                                        top: 16,
                                        start: pad,
                                        end: pad,
                                        bottom: 10,
                                      ),
                                      onTap: () {
                                        final route = bannerInfo.targetRoute
                                            ?.trim();
                                        if (route != null &&
                                            route.startsWith('/')) {
                                          context.push(route);
                                          return;
                                        }

                                        final productId = bannerInfo
                                            .targetProductId
                                            ?.trim();
                                        if (productId != null &&
                                            productId.isNotEmpty) {
                                          context.push('/product/$productId');
                                          return;
                                        }

                                        final category = bannerInfo
                                            .targetCategory
                                            ?.trim();
                                        if (category != null &&
                                            category.isNotEmpty) {
                                          context.push(
                                            Uri(
                                              pathSegments: [
                                                '',
                                                'category',
                                                category,
                                              ],
                                              queryParameters: {
                                                'filter': category,
                                              },
                                            ).toString(),
                                          );
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              
                              // Zone 1: Discovery Content (Categories)
                              HomeCategoriesSection(
                                categories: state.categories,
                              ),

                              // Zone 2: Flash Sale Products
                              HomeFlashSaleSection(
                                products: state.flashSaleProducts,
                                isLoading: state.isFlashSaleLoading,
                              ),

                              // Zone 3: Behavioral Recommendations (Personalized recommendations)
                              SliverToBoxAdapter(
                                key: homeBehavioralRecommendationsSectionKey,
                                child: const BehavioralRecommendationsSection(),
                              ),

                              // Zone 4: History / Context (Recently Viewed)
                              const HomeRecentlyViewedSection(),
                              
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  SearchHeaderDelegate({required this.child});

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
