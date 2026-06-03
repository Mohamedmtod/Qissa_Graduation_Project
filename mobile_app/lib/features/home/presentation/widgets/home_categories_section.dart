import 'package:flutter/material.dart';
import 'package:perfume_app/features/categories/data/models/category_model.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';
import 'package:perfume_app/features/home/presentation/widgets/home_section_header.dart';

class HomeCategoriesSection extends StatelessWidget {
  final List<CategoryModel> categories;

  const HomeCategoriesSection({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (categories.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeSectionHeader(
                title: l10n.labelCategories,
                padding: const EdgeInsetsDirectional.only(top: 24, bottom: 12),
              ),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        color: Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'لا توجد أقسام متاحة حالياً'
                            : 'No categories available at the moment',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CategorySection(
      title: l10n.labelCategories,
      titleFontSize: 22,
      paddingTop: 24,
      paddingBottom: 12,
      paddingLeft: 12,
      distanceBetweenCards: 12,
      sectionHeight: 110,
      itemCount: categories.length,
      photoCardHeight: 85,
      photoCardWidth: 85,
      descriptionFontSize: 12,
      cornerRadius: 50,
      icons: categories,
    );
  }
}
