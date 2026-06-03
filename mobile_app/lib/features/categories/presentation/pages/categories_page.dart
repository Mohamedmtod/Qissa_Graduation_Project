import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/categories/data/models/category_model.dart';
import 'package:perfume_app/features/home/presentation/manager/home_cubit.dart';
import 'package:perfume_app/features/home/presentation/manager/home_state.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final ScrollController scrollController = ScrollController();
  bool isAtTop = true;
  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (!mounted) return;
      final atTop = scrollController.offset <= 0;

      // عشان نقلل setState على الفاضي
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: true,
        title: CustomTextStyle(
          text: l10n.labelCategories,
          fontsize: FontSizes.h1,
          textColor: Theme.of(context).colorScheme.onSurface,
          bold: true,
        ),

        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: isAtTop ? Theme.of(context).colorScheme.surface : Colors.transparent),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            List<CategoryModel> categories = [];

            if (state is HomeSuccess) {
              categories = state.categories;
            } else if (state is HomeLoading) {
              return const SafeArea(
                child: CategoryListSkeleton(),
              );
            }

            if (categories.isEmpty && state is HomeSuccess) {
              categories = [
                CategoryModel(
                  id: '1',
                  name: l10n.categoryPerfumes,
                  categoryName: l10n.categoryPerfumes,
                  imageUrl: '',
                  sortOrder: 1,
                  query: 'perfume',
                ),
                CategoryModel(
                  id: '2',
                  name: l10n.categoryBokhoor,
                  categoryName: l10n.categoryBokhoor,
                  imageUrl: '',
                  sortOrder: 2,
                  query: 'bokhoor',
                ),
                CategoryModel(
                  id: '3',
                  name: l10n.categoryMabkhara,
                  categoryName: l10n.categoryMabkhara,
                  imageUrl: '',
                  sortOrder: 3,
                  query: 'mabkhara',
                ),
                CategoryModel(
                  id: '4',
                  name: l10n.categoryFawa7a,
                  categoryName: l10n.categoryFawa7a,
                  imageUrl: '',
                  sortOrder: 4,
                  query: 'fawa7a',
                ),
                CategoryModel(
                  id: '5',
                  name: l10n.categoryWatches,
                  categoryName: l10n.categoryWatches,
                  imageUrl: '',
                  sortOrder: 5,
                  query: 'watch',
                ),
                CategoryModel(
                  id: '6',
                  name: l10n.categorySunglasses,
                  categoryName: l10n.categorySunglasses,
                  imageUrl: '',
                  sortOrder: 6,
                  query: 'sunglass',
                ),
              ];
            }

            return ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelFragranceFamiliesTitle,
                            fontsize: 28,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: PerfCatCards(
                              imageUrl:
                                  "https://lh3.googleusercontent.com/aida-public/AB6AXuCy23eCacdDD7jN-RwdxrGtwjNt6YCqjAb8TRIGi7meOdfJusuiW2WvBgzLEYchnESy8aBBV-_ns5uccnM9puC-tRsR9yXINjTXtn19Zo2kzpuW7GoMzBJKj2YUaQ6xjJYddSpaU3QLxglj3T1TR_0C47Ab5qmMPRtZ5gW1HW-YLWbnG2DghX-J4tURenA1rtv4YtQuD4241fsSputjODLhvoc9yBN7EfU137tLPcDzFdShyijtoERYtAX2dK0lBFTAVTJh0NpLXGTp",
                              catName: l10n.labelOptionFloral,
                              filterValue: "Floral",
                              catDescription: l10n.descFloral,
                            ),
                          ),

                          SizedBox(width: 8),
                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionFruity,
                              filterValue: 'Fruity',

                              imageUrl:
                                  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/products/2026-04-15/d333d29d-e259-41d0-b6bd-6b3a13340cba-fruity-bright-juicy.png',

                              catDescription: l10n.descFruity,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionOriental,
                              filterValue: 'Oriental',

                              imageUrl:
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBXTJNluvZWpaMpm2fHkAVw-0YBNAlQudxOvcE6cjKS7M51GEiIbUWqmq3UpVXVwu8zbZKJZ7PSuC_xPo2psx6RB4HQsL9ul5T3Kk0N2j_f3MqmPeg2HXFWPzRBnLyg_bpGBmeuaULZmz1Ol14hTNN8d6IE2ysNyS664ebtLG6HulbnskINZbKV6Y6L9shtAg6RUHm3NeK0YxdBLavockxOBtfBqWp_YcR8sC2Od2bVnlaGF3WQzp2QGQZMuuHxS8Id0Txwm-wuQjcd',

                              catDescription: l10n.descOriental,
                            ),
                          ),

                          SizedBox(width: 8),

                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionWoody,
                              filterValue: 'Woody',

                              imageUrl:
                                  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/categories/2026-04-15/637179ed-b87f-4187-8a59-895c324093b3-woody.png',

                              catDescription: l10n.descWoody,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: PerfCatCards(
                              imageUrl:
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCSjKsXSYgxEc-yMnlgEzw6p2wcYtTEBkYlTD1zcqWIo1TfHfzOnoq-NYugiIB0I8O5eIalCmoCwy3Wx90o9LnhBsrO8CumUBAaIur8uy7ht9ibjXEmTddIaBm63k4PGIyK5tCjWtAAVptAgt9TNqZgoDnvdFJ_wotcnjFErGZ0f_yc4kQtcgAkhT45THgHBkulz29ZcC7V7yGZJc7cPhbqj6t91D2WEmouI2ITJHdZJ3_8eiAyAYNZqTkk3SwQtrJtmvsSqllcGrqo',
                              catName: l10n.labelOptionFresh,
                              filterValue: "Fresh",
                              catDescription: l10n.descFresh,
                              height: 225,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionGourmand,
                              filterValue: 'Gourmand',

                              imageUrl:
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAVZZP895T67MRvr00QdWJS8hZIwQypfhQNVmm56BPlK2xCcJpWE-lI5ggQE2cWulE3b6WPuy1ATWI0UPvKTeW2Y9_V2HWYCA5haoS_SQpX_h1LdG65DsgkJC1P9WlnzrFrhf4JSv7A34RX8YdiZGuY9f9qrjBLOcilLnplvke9SprnFICZjpFNufaD-oN1YvH34mrGX8_lURarDbNSbeMegwtK_kboXGy7BkxmmEmh0wUihTBfGVs_kcCz4vHLlaDKw5xxYIkrRFGT',

                              catDescription: l10n.descGourmand,
                            ),
                          ),

                          SizedBox(width: 8),

                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionLeather,
                              filterValue: 'Leather',

                              imageUrl:
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuD5q_WZc_11X8o-DmU5x8UXmTRq-hvxBVl4QsVUapCDsyA_klMOMuRJx4X4jM57-qMD0pYz5rRszSthtljgc0TjSOXvpd6qqZM1uT3WBEYJca4xs1X7imb25Yy-PwdIYGcEc92HBz0uzBWj8lJsLKwtrV_VfBLSRZB1xgH-6vWYi-bnLrEhUrRAks5BL66SnQHVBn5rVcPy4Fk-OgHwEPgz3yOH1E3UOih9ai5AA_teiOfOhXo2PRRq2skz36ySLFuhTSqT0qAHMuK9',

                              catDescription: l10n.descLeather,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: PerfCatCards(
                              catName: l10n.labelOptionOud,
                              filterValue: 'Oud',

                              imageUrl:
                                  'https://pub-578625c66b1749c2b5b2e0c0a89a26b5.r2.dev/categories/2026-04-15/0e36a5e4-591f-486a-9514-3f3f85dbaeb6-oudy.png',

                              catDescription: l10n.descOud,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(18.0),
                        constraints: const BoxConstraints(maxHeight: 220),
                        width: double.infinity,

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextStyle(
                              bold: true,
                              fontsize: 24,
                              textColor: Theme.of(context).colorScheme.onSurface,
                              text: l10n.labelUnsureWhereToBegin,
                            ),
                            SizedBox(height: 8),
                            CustomTextStyle(
                              bold: true,
                              fontsize: 14,
                              textColor: Theme.of(context).colorScheme.onSurface,
                              text: l10n.msgAiAssistantHelp,
                            ),
                            Spacer(),
                            ElevatedButton(
                              onPressed: navigateToMainLayout(
                                context,
                                Go.aiChat,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 1.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: CustomTextStyle(
                                text: l10n.btnStartChatting.toUpperCase(),
                                fontsize: 16,
                                textColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLowest,
                                bold: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PerfCatCards extends StatelessWidget {
  final String imageUrl;
  final String catName;
  final String filterValue;
  final String catDescription;
  final double height;

  const PerfCatCards({
    super.key,
    required this.imageUrl,
    required this.catName,
    required this.filterValue,
    required this.catDescription,
    this.height = 225,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: () {
          context.push(
            Uri(
              pathSegments: ['', 'category', catName],
              queryParameters: {'family': filterValue},
            ).toString(),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SkeletonWrapper(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: lighterBeige2,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.spa_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest,
                      size: 34,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextStyle(
                      bold: true,
                      fontsize: 19,
                      textColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest,
                      text: catName,
                    ),
                    const SizedBox(height: 4),
                    CustomTextStyle(
                      fontsize: 10,
                      textColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLowest
                          .withValues(alpha: 0.8),
                      text: catDescription.toUpperCase(),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
