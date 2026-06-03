import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/products/presentation/manager/search_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/search_state.dart';
import 'package:perfume_app/features/products/presentation/widgets/filter_section.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/cards.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/widgets/skeletons.dart';
import 'package:perfume_app/widgets/nav_bar.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';

class CategoryProductsPage extends StatefulWidget {
  final String categoryName;
  final String categoryFilter;
  final String? fragranceFamily;

  const CategoryProductsPage({
    super.key,
    required this.categoryName,
    required this.categoryFilter,
    this.fragranceFamily,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final ScrollController _scrollController = ScrollController();

  // Active filter state (tracked locally for the chips bar)
  String? _activeGender;
  String? _activeSeason;
  String? _activeFamily;

  bool get _isViewedBeforeCategory =>
      widget.categoryFilter.toLowerCase() == 'viewed-before';
  bool get _isFlashSaleCategory =>
      widget.categoryFilter.toLowerCase() == 'flash-sale';
  bool get _hasActiveFilters =>
      _activeGender != null || _activeSeason != null || _activeFamily != null;

  @override
  void initState() {
    super.initState();
    if (_isViewedBeforeCategory) {
      context.read<SearchCubit>().searchByViewedBefore();
    } else if (_isFlashSaleCategory) {
      context.read<SearchCubit>().searchFlashSale();
    } else if (widget.fragranceFamily != null &&
        widget.fragranceFamily!.trim().isNotEmpty) {
      context.read<SearchCubit>().filterWithinCategory(
        categoryName: '',
        fragranceFamily: widget.fragranceFamily!.trim(),
      );
    } else {
      context.read<SearchCubit>().searchByCategory(widget.categoryFilter);
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchCubit>().loadMore();
    }
  }

  // True when this page was opened from a fragrance-family card
  bool get _isFamilyPage =>
      widget.fragranceFamily != null &&
      widget.fragranceFamily!.trim().isNotEmpty;

  /// Re-runs the original page query with no extra filters.
  void _reloadBaseResults() {
    if (_isViewedBeforeCategory) {
      context.read<SearchCubit>().searchByViewedBefore();
    } else if (_isFlashSaleCategory) {
      context.read<SearchCubit>().searchFlashSale();
    } else if (_isFamilyPage) {
      // Family pages base query = filter by family only, no category
      context.read<SearchCubit>().filterWithinCategory(
        categoryName: '',
        fragranceFamily: widget.fragranceFamily!.trim(),
      );
    } else {
      context.read<SearchCubit>().searchByCategory(widget.categoryFilter);
    }
  }

  void _applyFilters(String? gender, String? season, String? family) {
    // If every param is null → just clear and reload base.
    if (gender == null && season == null && family == null) {
      setState(() {
        _activeGender = null;
        _activeSeason = null;
        _activeFamily = null;
      });
      _reloadBaseResults();
      return;
    }

    setState(() {
      _activeGender = gender;
      _activeSeason = season;
      _activeFamily = family;
    });

    // Determine category name to pass:
    //  - flash-sale / viewed-before / family pages → '' (no categoryName filter)
    //  - normal category pages → widget.categoryFilter
    final String categoryNameForQuery =
        (_isFlashSaleCategory || _isViewedBeforeCategory || _isFamilyPage)
        ? ''
        : widget.categoryFilter;

    // For family pages, if the user didn't pick a new family in the sheet,
    // we keep the page's original family so results stay on-theme.
    final String? effectiveFamily =
        family ?? (_isFamilyPage ? widget.fragranceFamily!.trim() : null);

    context.read<SearchCubit>().filterWithinCategory(
      categoryName: categoryNameForQuery,
      gender: gender,
      season: season,
      fragranceFamily: effectiveFamily,
    );
  }

  void _clearFilters() {
    setState(() {
      _activeGender = null;
      _activeSeason = null;
      _activeFamily = null;
    });
    _reloadBaseResults();
  }

  void _removeFilter(String type) {
    String? newGender = _activeGender;
    String? newSeason = _activeSeason;
    String? newFamily = _activeFamily;

    switch (type) {
      case 'gender':
        newGender = null;
        break;
      case 'season':
        newSeason = null;
        break;
      case 'family':
        newFamily = null;
        break;
    }
    _applyFilters(newGender, newSeason, newFamily);
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => FilterSection(
          initialGender: _activeGender,
          initialSeason: _activeSeason,
          // Pre-select the page's family when on a family page
          initialFamily: _activeFamily ?? widget.fragranceFamily,
          onApply: _applyFilters,
        ),
      ),
    );
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
          text: widget.categoryName,
          fontsize: 18,
          textColor: Theme.of(context).colorScheme.onSurface,
          bold: true,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GoBackIcon(navigateTo: () => Navigator.pop(context)),
        leadingWidth: 30,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              GoRouter.of(context).push('/search');
            },
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(
                  _hasActiveFilters ? Icons.tune : Icons.tune_outlined,
                  color: _hasActiveFilters
                      ? AppTheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _openFilter,
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Active filter chips bar ─────────────────────────────────
          if (_hasActiveFilters)
            _ActiveFilterChipsBar(
              activeGender: _activeGender,
              activeSeason: _activeSeason,
              activeFamily: _activeFamily,
              onRemove: _removeFilter,
              onClearAll: _clearFilters,
            ),

          // ── Products grid ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: ProductGridSkeleton(
                        crossAxisCount: 2,
                        itemCount: 10,
                      ),
                    );
                  }

                  List products = [];
                  bool hasMore = false;
                  bool isLoadingMore = false;
                  bool isOfflineFallback = false;

                  if (state is SearchSuccess) {
                    products = state.products;
                    hasMore = state.hasMore;
                    isOfflineFallback = state.isOfflineFallback;
                  } else if (state is SearchLoadingMore) {
                    products = state.currentProducts;
                    isLoadingMore = true;
                    hasMore = true;
                  } else if (state is SearchError) {
                    return Center(
                      child: Text(
                        resolveUserFacingMessage(
                          context,
                          state.message,
                          fallback: l10n.msgSearchLoadFailed,
                        ),
                      ),
                    );
                  }

                  if (products.isEmpty && state is! SearchInitial) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 52,
                            color: AppTheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isViewedBeforeCategory
                                ? l10n.msgNoRecentlyViewedProducts
                                : _isFlashSaleCategory
                                ? l10n.msgNoProductsFoundForCategory(
                                    'Flash Sale',
                                  )
                                : l10n.msgNoProductsFoundForCategory(
                                    widget.categoryName,
                                  ),
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_hasActiveFilters) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: Text(l10n.labelClearFilters),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  if (state is SearchInitial) {
                    return const SizedBox();
                  }

                  final itemCountForLoading =
                      products.length + (hasMore || isLoadingMore ? 1 : 0);

                  return Column(
                    children: [
                      if (isOfflineFallback)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: _OfflineResultsBanner(),
                        ),
                      Expanded(
                        child: VerticalProductsCard(
                          itemCount: itemCountForLoading,
                          products: products,
                          scale: .7,
                          scrollController: _scrollController,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SharedNavBar(currentIndex: Go.home),
    );
  }
}

// ── Active Filter Chips Bar ─────────────────────────────────────────────────

class _ActiveFilterChipsBar extends StatelessWidget {
  final String? activeGender;
  final String? activeSeason;
  final String? activeFamily;
  final void Function(String type) onRemove;
  final VoidCallback onClearAll;

  const _ActiveFilterChipsBar({
    required this.activeGender,
    required this.activeSeason,
    required this.activeFamily,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Clear all button
            _FilterChip(
              label: AppLocalizations.of(context).labelClearFilters,
              isActive: false,
              isClearAll: true,
              onTap: onClearAll,
            ),
            const SizedBox(width: 6),
            if (activeGender != null) ...[
              _FilterChip(
                label: activeGender!,
                isActive: true,
                onTap: () => onRemove('gender'),
              ),
              const SizedBox(width: 6),
            ],
            if (activeSeason != null) ...[
              _FilterChip(
                label: activeSeason!,
                isActive: true,
                onTap: () => onRemove('season'),
              ),
              const SizedBox(width: 6),
            ],
            if (activeFamily != null) ...[
              _FilterChip(
                label: activeFamily!,
                isActive: true,
                onTap: () => onRemove('family'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isClearAll;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isClearAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isClearAll
              ? Colors.transparent
              : isActive
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isClearAll
                ? AppTheme.outlineVariant.withValues(alpha: 0.5)
                : isActive
                ? AppTheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isClearAll
                    ? AppTheme.onSurfaceVariant
                    : isActive
                    ? AppTheme.primary
                    : AppTheme.onSurface,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Offline Banner ──────────────────────────────────────────────────────────

class _OfflineResultsBanner extends StatelessWidget {
  const _OfflineResultsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing saved results. Some prices or stock may be outdated.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
