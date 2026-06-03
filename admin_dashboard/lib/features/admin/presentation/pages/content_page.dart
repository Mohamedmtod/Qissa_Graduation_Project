import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_content_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_view_models.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_feature_highlight.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_content_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_media_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_content_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_content_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_media_picker_dialog.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_product_editor_dialog.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class ContentPage extends StatelessWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminContentCubit(
        context.read<AdminContentRepository>(),
        logger: context.read<AdminActionLogger>(),
      )..loadContent(),
      child: const _ContentViewBody(),
    );
  }
}

enum _ContentTopTab { overview, workflows }

class _ContentViewBody extends StatefulWidget {
  const _ContentViewBody();

  @override
  State<_ContentViewBody> createState() => _ContentViewBodyState();
}

class _ContentViewBodyState extends State<_ContentViewBody> {
  _ContentTopTab _activeTab = _ContentTopTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocListener<AdminContentCubit, AdminContentState>(
      listenWhen: (previous, current) =>
          previous.feedbackMessage != current.feedbackMessage &&
          current.feedbackMessage != null,
      listener: (context, state) {
        final message = state.feedbackMessage;
        if (message == null) {
          return;
        }
        _showMessage(context, message);
        context.read<AdminContentCubit>().clearFeedback();
      },
      child: Column(
        children: [
          SharedTopbar(
            title: l10n.t('content.topbarTitle'),
            searchHint: l10n.t('content.searchHint'),
            tabs: [
              TopbarTab(
                label: l10n.t('common.overview'),
                active: _activeTab == _ContentTopTab.overview,
                onTap: () =>
                    setState(() => _activeTab = _ContentTopTab.overview),
              ),
              TopbarTab(
                label: l10n.t('content.workflows'),
                active: _activeTab == _ContentTopTab.workflows,
                onTap: () =>
                    setState(() => _activeTab = _ContentTopTab.workflows),
              ),
            ],
            onSearchChanged: context.read<AdminContentCubit>().setSearchQuery,
          ),
          Expanded(
            child: BlocBuilder<AdminContentCubit, AdminContentState>(
              builder: (context, state) {
                final snapshot = state.snapshot;
                if (state.isLoading && snapshot == null) {
                  return AdminLoadingState(
                    title: l10n.t('content.loadingTitle'),
                  );
                }

                if (state.errorMessage != null) {
                  return AdminErrorState(
                    title: l10n.t('content.errorTitle'),
                    message: state.errorMessage!,
                    onRetry: () =>
                        context.read<AdminContentCubit>().loadContent(),
                  );
                }

                if (snapshot == null) {
                  return AdminEmptyState(
                    title: l10n.t('content.emptyTitle'),
                    message: l10n.t('content.emptyMessage'),
                    actionLabel: l10n.t('common.retry'),
                    onAction: () =>
                        context.read<AdminContentCubit>().loadContent(),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          runSpacing: 18,
                          spacing: 18,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 650),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AdminSectionLabel(
                                    label: l10n.t('content.editorialSystem'),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.t('content.heroTitle'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                          fontSize: 40,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    l10n.t('content.heroDescription'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AdminSecondaryButton(
                                  label: l10n.t('content.duplicateDraft'),
                                  icon: Icons.copy_outlined,
                                  onPressed: snapshot.banners.isEmpty
                                      ? null
                                      : () =>
                                            _duplicateDraftFromCurrentSnapshot(
                                              context,
                                              snapshot,
                                            ),
                                ),
                                AdminPrimaryButton(
                                  label: switch (state.view) {
                                    AdminContentView.products => l10n.t(
                                      'content.newProduct',
                                    ),
                                    AdminContentView.banners => l10n.t(
                                      'content.newBanner',
                                    ),
                                    AdminContentView.categories => l10n.t(
                                      'content.newCategory',
                                    ),
                                    AdminContentView.storeInfo => l10n.t(
                                      'content.storeInfo',
                                    ),
                                  },
                                  icon: Icons.add,
                                  onPressed:
                                      state.view == AdminContentView.storeInfo
                                      ? null
                                      : () => _showCreateDialog(
                                          context,
                                          state.view,
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<AdminContentView>(
                          segments: [
                            ButtonSegment(
                              value: AdminContentView.products,
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(l10n.t('content.products')),
                            ),
                            ButtonSegment(
                              value: AdminContentView.banners,
                              icon: const Icon(Icons.view_carousel_outlined),
                              label: Text(l10n.t('content.banners')),
                            ),
                            ButtonSegment(
                              value: AdminContentView.categories,
                              icon: const Icon(Icons.grid_view_outlined),
                              label: Text(l10n.t('content.categories')),
                            ),
                            ButtonSegment(
                              value: AdminContentView.storeInfo,
                              icon: const Icon(Icons.storefront_outlined),
                              label: Text(l10n.t('content.storeInfo')),
                            ),
                          ],
                          selected: {state.view},
                          onSelectionChanged: (selection) => context
                              .read<AdminContentCubit>()
                              .setView(selection.first),
                        ),
                        const SizedBox(height: 28),
                        if (_activeTab == _ContentTopTab.overview)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked = constraints.maxWidth < 1180;

                              if (stacked) {
                                return Column(
                                  children: [
                                    _ContentFeatureCard(
                                      featuredEditorial:
                                          snapshot.featuredEditorial,
                                      onOpenEditor:
                                          _canOpenEditorialEditor(snapshot)
                                          ? () => _openFeaturedEditorialEditor(
                                              context,
                                              snapshot,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 24),
                                    _BannerQueueCard(
                                      banners: state.visibleBanners,
                                    ),
                                    const SizedBox(height: 24),
                                    _CategoryArchitectureCard(
                                      categories: state.visibleCategories,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _ContentFeatureCard(
                                      featuredEditorial:
                                          snapshot.featuredEditorial,
                                      onOpenEditor:
                                          _canOpenEditorialEditor(snapshot)
                                          ? () => _openFeaturedEditorialEditor(
                                              context,
                                              snapshot,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        _BannerQueueCard(
                                          banners: state.visibleBanners,
                                        ),
                                        const SizedBox(height: 24),
                                        _CategoryArchitectureCard(
                                          categories: state.visibleCategories,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        else
                          AdminSurfaceCard(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                const Icon(Icons.account_tree_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(l10n.t('content.workflows')),
                                ),
                                AdminSecondaryButton(
                                  label: l10n.t('content.openEditor'),
                                  onPressed: _canOpenEditorialEditor(snapshot)
                                      ? () => _openFeaturedEditorialEditor(
                                          context,
                                          snapshot,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (state.view) {
                            AdminContentView.products => _ProductPipeline(
                              products: state.visibleProducts,
                              canLoadMore: state.canLoadMoreProducts,
                              isLoadingMore: state.isLoadingMoreProducts,
                            ),
                            AdminContentView.banners => _BannerPipeline(
                              banners: state.visibleBanners,
                            ),
                            AdminContentView.categories => _CategoryPipeline(
                              categories: state.visibleCategories,
                            ),
                            AdminContentView.storeInfo => _StoreInfoPanel(
                              info: snapshot.businessInfo,
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreInfoPanel extends StatefulWidget {
  const _StoreInfoPanel({required this.info});

  final AdminBusinessInfo info;

  @override
  State<_StoreInfoPanel> createState() => _StoreInfoPanelState();
}

class _StoreInfoPanelState extends State<_StoreInfoPanel> {
  late TextEditingController _storeName;
  late TextEditingController _addressAr;
  late TextEditingController _addressEn;
  late TextEditingController _phone;
  late TextEditingController _whatsapp;
  late TextEditingController _facebookUrl;
  late TextEditingController _instagramUrl;
  late TextEditingController _websiteUrl;
  late TextEditingController _openingHoursAr;
  late TextEditingController _openingHoursEn;
  late TextEditingController _deliveryInfoAr;
  late TextEditingController _deliveryInfoEn;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.info);
  }

  @override
  void didUpdateWidget(covariant _StoreInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info != widget.info) {
      _disposeControllers();
      _syncControllers(widget.info);
    }
  }

  void _syncControllers(AdminBusinessInfo info) {
    _storeName = TextEditingController(text: info.storeName);
    _addressAr = TextEditingController(text: info.addressAr);
    _addressEn = TextEditingController(text: info.addressEn);
    _phone = TextEditingController(text: info.phone);
    _whatsapp = TextEditingController(text: info.whatsapp);
    _facebookUrl = TextEditingController(text: info.facebookUrl);
    _instagramUrl = TextEditingController(text: info.instagramUrl);
    _websiteUrl = TextEditingController(text: info.websiteUrl);
    _openingHoursAr = TextEditingController(text: info.openingHoursAr);
    _openingHoursEn = TextEditingController(text: info.openingHoursEn);
    _deliveryInfoAr = TextEditingController(text: info.deliveryInfoAr);
    _deliveryInfoEn = TextEditingController(text: info.deliveryInfoEn);
    _isPublished = info.isPublished;
  }

  void _disposeControllers() {
    _storeName.dispose();
    _addressAr.dispose();
    _addressEn.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _facebookUrl.dispose();
    _instagramUrl.dispose();
    _websiteUrl.dispose();
    _openingHoursAr.dispose();
    _openingHoursEn.dispose();
    _deliveryInfoAr.dispose();
    _deliveryInfoEn.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('content.storeInfoTitle'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.t('content.storeInfoDescription')),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AdminSecondaryButton(
                    label: l10n.t('content.recomputeSalesStats'),
                    icon: Icons.query_stats_outlined,
                    onPressed: () => context
                        .read<AdminContentCubit>()
                        .recomputeProductPublicStats(),
                  ),
                  AdminPrimaryButton(
                    label: l10n.t('content.saveStoreInfo'),
                    icon: Icons.save_outlined,
                    onPressed: () => context
                        .read<AdminContentCubit>()
                        .updateBusinessInfo(_buildInfo()),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPublished,
            onChanged: (value) => setState(() => _isPublished = value),
            title: Text(l10n.t('content.publishStoreInfo')),
            subtitle: Text(l10n.t('content.publishStoreInfoHint')),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 900;
              final fields = [
                _field(l10n.t('content.storeName'), _storeName),
                _field(l10n.t('content.phone'), _phone),
                _field(l10n.t('content.whatsapp'), _whatsapp),
                _field(l10n.t('content.addressAr'), _addressAr, maxLines: 2),
                _field(l10n.t('content.addressEn'), _addressEn, maxLines: 2),
                _field(
                  l10n.t('content.openingHoursAr'),
                  _openingHoursAr,
                  maxLines: 2,
                ),
                _field(
                  l10n.t('content.openingHoursEn'),
                  _openingHoursEn,
                  maxLines: 2,
                ),
                _field(
                  l10n.t('content.deliveryInfoAr'),
                  _deliveryInfoAr,
                  maxLines: 2,
                ),
                _field(
                  l10n.t('content.deliveryInfoEn'),
                  _deliveryInfoEn,
                  maxLines: 2,
                ),
                _field(l10n.t('content.instagramUrl'), _instagramUrl),
                _field(l10n.t('content.facebookUrl'), _facebookUrl),
                _field(l10n.t('content.websiteUrl'), _websiteUrl),
              ];
              if (!twoColumns) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: fields
                    .map(
                      (field) => SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: field,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  AdminBusinessInfo _buildInfo() {
    return AdminBusinessInfo(
      storeName: _storeName.text,
      addressAr: _addressAr.text,
      addressEn: _addressEn.text,
      phone: _phone.text,
      whatsapp: _whatsapp.text,
      facebookUrl: _facebookUrl.text,
      instagramUrl: _instagramUrl.text,
      websiteUrl: _websiteUrl.text,
      openingHoursAr: _openingHoursAr.text,
      openingHoursEn: _openingHoursEn.text,
      deliveryInfoAr: _deliveryInfoAr.text,
      deliveryInfoEn: _deliveryInfoEn.text,
      isPublished: _isPublished,
    );
  }
}

class _ContentFeatureCard extends StatelessWidget {
  const _ContentFeatureCard({
    required this.featuredEditorial,
    required this.onOpenEditor,
  });

  final AdminFeatureHighlight? featuredEditorial;
  final VoidCallback? onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final item = featuredEditorial;
    if (item == null) {
      return SizedBox(
        height: 360,
        child: AdminSurfaceCard(
          padding: const EdgeInsets.all(28),
          child: AdminEmptyState(
            title: l10n.t('content.emptyTitle'),
            message: l10n.t('content.emptyMessage'),
            icon: Icons.article_outlined,
          ),
        ),
      );
    }
    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          Positioned.fill(
            child: AdminNetworkImage(
              imageUrl: item.imageUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 28,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xF2171716),
                    Color(0x78171716),
                    Color(0x1A171716),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminSectionLabel(
                  label: l10n.t('content.featuredEditorial'),
                  color: AppTheme.primaryFixed,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.resolve(item.title),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    l10n.resolve(item.description),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdminPrimaryButton(
                  label: item.actionLabel == null
                      ? l10n.t('content.openEditor')
                      : l10n.resolve(item.actionLabel!),
                  onPressed: onOpenEditor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerQueueCard extends StatelessWidget {
  const _BannerQueueCard({required this.banners});

  final List<BannerEntry> banners;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(24),
      color: AppTheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('content.bannerQueue'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 18),
          ...banners.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.isActive
                          ? AppTheme.secondary
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.resolve(entry.title),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppTheme.primary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${l10n.resolve(entry.slot)} - ${l10n.resolve(entry.mood)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    l10n.resolve(entry.performance),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showBannerEditDialog(context, entry),
                    tooltip: l10n.t('common.edit'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryArchitectureCard extends StatelessWidget {
  const _CategoryArchitectureCard({required this.categories});

  final List<CategoryEntry> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(24),
      color: AppTheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('content.categoryArchitecture'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories
                .map(
                  (entry) => AdminPill(
                    label:
                        '${l10n.resolve(entry.name)} (${entry.productCount})',
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    foregroundColor: AppTheme.primary,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ProductPipeline extends StatelessWidget {
  const _ProductPipeline({
    required this.products,
    required this.canLoadMore,
    required this.isLoadingMore,
  });

  final List<ProductEntry> products;
  final bool canLoadMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return SizedBox(
      key: const ValueKey('products'),
      width: double.infinity,
      child: AdminSurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('content.productPipeline'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            ...products.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _PipelineRow(
                  title: l10n.resolve(entry.title),
                  subtitle:
                      '${l10n.resolve(entry.collection)} - ${_formatProductPrice(entry.effectivePrice)} - ${l10n.resolve(entry.updatedAt)}',
                  note: l10n.resolve(entry.notes),
                  statusLabel: l10n.resolve(entry.status),
                  imageUrl: entry.imageUrls.isNotEmpty ? entry.imageUrls.first : entry.imageUrl,
                  leadingIcon: Icons.inventory_2_outlined,
                  actionButtons: [
                    AdminSecondaryButton(
                      label: entry.isVisible ? l10n.t('content.action.hide') : l10n.t('content.action.unhide'),
                      onPressed: () => context
                          .read<AdminContentCubit>()
                          .setProductVisibility(entry.id, !entry.isVisible),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('content.action.archive', fallback: 'Archive'),
                      onPressed: entry.isArchived
                          ? null
                          : () => context
                                .read<AdminContentCubit>()
                                .archiveProduct(entry.id),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('common.edit'),
                      onPressed: () => _showProductEditDialog(context, entry),
                    ),
                  ],
                ),
              );
            }),
            if (canLoadMore || isLoadingMore) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: AdminSecondaryButton(
                  label: isLoadingMore
                      ? l10n.t('content.loadingMoreProducts')
                      : l10n.t('content.loadMoreProducts'),
                  icon: Icons.expand_more,
                  onPressed: isLoadingMore
                      ? null
                      : () => context
                            .read<AdminContentCubit>()
                            .loadMoreProducts(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BannerPipeline extends StatelessWidget {
  const _BannerPipeline({required this.banners});

  final List<BannerEntry> banners;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return SizedBox(
      key: const ValueKey('banners'),
      width: double.infinity,
      child: AdminSurfaceCard(
        padding: const EdgeInsets.all(24),
        color: AppTheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('content.campaignQueue'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            ...banners.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _PipelineRow(
                  title: l10n.resolve(entry.title),
                  subtitle: l10n.resolve(entry.slot),
                  note: l10n.resolve(entry.mood),
                  statusLabel: l10n.resolve(entry.performance),
                  imageUrl: entry.imageUrl,
                  leadingIcon: Icons.view_carousel_outlined,
                  actionButtons: [
                    AdminSecondaryButton(
                      label: l10n.t('content.action.toggle', fallback: 'Toggle'),
                      onPressed: () =>
                          context.read<AdminContentCubit>().updateBanner(
                            entry.id,
                            AdminBannerUpsertInput(
                              title: entry.title,
                              imageUrl: entry.imageUrl,
                              subtitle: entry.mood,
                              targetPath: entry.targetPath,
                              isActive: !entry.isActive,
                              queuePosition: entry.queuePosition,
                            ),
                          ),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('content.action.moveUp', fallback: 'Move Up'),
                      onPressed: entry.queuePosition == 0
                          ? null
                          : () => _moveBanner(context, entry, -1),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('common.delete'),
                      onPressed: () => context
                          .read<AdminContentCubit>()
                          .deleteBanner(entry.id),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('common.edit'),
                      onPressed: () => _showBannerEditDialog(context, entry),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CategoryPipeline extends StatelessWidget {
  const _CategoryPipeline({required this.categories});

  final List<CategoryEntry> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return SizedBox(
      key: const ValueKey('categories'),
      width: double.infinity,
      child: AdminSurfaceCard(
        padding: const EdgeInsets.all(24),
        color: AppTheme.surfaceContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('content.categoryRegistry'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            ...categories.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _PipelineRow(
                  title: l10n.resolve(entry.name),
                  subtitle:
                      '${entry.productCount} ${l10n.t('content.productsWord')}',
                  note: l10n.resolve(entry.description),
                  statusLabel: l10n.t('content.visible'),
                  imageUrl: entry.imageUrl,
                  leadingIcon: Icons.category_outlined,
                  actionButtons: [
                    AdminSecondaryButton(
                      label: entry.isActive ? l10n.t('content.action.hide') : l10n.t('content.action.show'),
                      onPressed: () => context
                          .read<AdminContentCubit>()
                          .setCategoryVisibility(entry.id, !entry.isActive),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('content.action.moveUp', fallback: 'Move Up'),
                      onPressed: entry.queuePosition == 0
                          ? null
                          : () => _moveCategory(context, entry, -1),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('common.delete'),
                      onPressed: () => context
                          .read<AdminContentCubit>()
                          .deleteCategory(entry.id),
                    ),
                    AdminSecondaryButton(
                      label: l10n.t('common.edit'),
                      onPressed: () => _showCategoryEditDialog(context, entry),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.statusLabel,
    this.actionButtons = const [],
    this.imageUrl,
    this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final String note;
  final String statusLabel;
  final List<Widget> actionButtons;
  final String? imageUrl;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      color: Colors.white,
      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 8,
          offset: const Offset(0, 2),
        )
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            AdminNetworkImage(
              imageUrl: imageUrl!,
              width: 72,
              height: 72,
              borderRadius: 12,
            ),
            const SizedBox(width: 16),
          ] else ...[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                leadingIcon ?? Icons.image_not_supported_outlined,
                color: AppTheme.primary.withValues(alpha: 0.5),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AdminPill(
                      label: statusLabel,
                      backgroundColor: AppTheme.surfaceContainerHighest,
                      foregroundColor: AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actionButtons,
          ),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}

void _duplicateDraftFromCurrentSnapshot(
  BuildContext context,
  dynamic snapshot,
) {
  final l10n = context.read<AdminLocaleController>();
  final cubit = context.read<AdminContentCubit>();
  final source = snapshot.banners.isNotEmpty ? snapshot.banners.first : null;
  if (source == null) {
    _showMessage(context, l10n.t('content.emptyMessage'));
    return;
  }

  cubit.createBanner(
    AdminBannerUpsertInput(
      title: '${source.title} (Copy)',
      imageUrl: source.imageUrl,
      subtitle: source.mood,
      targetPath: source.targetPath,
      isActive: false,
      queuePosition: source.queuePosition + 1,
    ),
  );
}

bool _canOpenEditorialEditor(dynamic snapshot) =>
    snapshot.banners.isNotEmpty || snapshot.products.isNotEmpty;

void _openFeaturedEditorialEditor(BuildContext context, dynamic snapshot) {
  final l10n = context.read<AdminLocaleController>();
  if (snapshot.banners.isNotEmpty) {
    _showBannerEditDialog(context, snapshot.banners.first);
    return;
  }
  if (snapshot.products.isNotEmpty) {
    _showProductEditDialog(context, snapshot.products.first);
    return;
  }

  _showMessage(context, l10n.t('content.emptyMessage'));
}

void _showCreateDialog(BuildContext context, AdminContentView view) {
  switch (view) {
    case AdminContentView.products:
      _showProductEditDialog(context, null);
      return;
    case AdminContentView.banners:
      _showBannerEditDialog(context, null);
      return;
    case AdminContentView.categories:
      _showCategoryEditDialog(context, null);
      return;
    case AdminContentView.storeInfo:
      return;
  }
}

void _showProductEditDialog(BuildContext context, ProductEntry? entry) {
  final l10n = context.read<AdminLocaleController>();
  final cubit = context.read<AdminContentCubit>();
  showAdminProductEditorDialog(
    context,
    title: entry == null
        ? l10n.t('content.createProduct')
        : l10n.t('content.editProduct'),
    initial: entry == null
        ? const AdminProductEditorInitial()
        : AdminProductEditorInitial(
            name: entry.title,
            nameAr: entry.nameAr,
            brand: entry.brand,
            brandAr: entry.brandAr,
            aliases: entry.aliases,
            aliasesAr: entry.aliasesAr,
            description: entry.notes,
            price: entry.price,
            size: entry.size,
            salePrice: entry.salePrice,
            categoryName: entry.collection,
            stock: entry.stock,
            isActive: entry.isVisible,
            isBestSeller: entry.isBestSeller,
            isNew: entry.isNew,
            gender: entry.gender,
            season: entry.season,
            time: entry.time,
            occasion: entry.occasion,
            intensity: entry.intensity,
            fragranceFamily: entry.fragranceFamily,
            topNotes: entry.topNotes,
            middleNotes: entry.middleNotes,
            baseNotes: entry.baseNotes,
            tags: entry.tags,
            imageUrls: entry.imageUrls.isNotEmpty
                ? entry.imageUrls
                : <String>[
                    if (entry.imageUrl.trim().isNotEmpty) entry.imageUrl,
                  ],
          ),
    onSubmit: (result) {
      final payload = AdminProductUpsertInput(
        name: result.name,
        nameAr: result.nameAr,
        brand: result.brand,
        brandAr: result.brandAr,
        aliases: result.aliases,
        aliasesAr: result.aliasesAr,
        categoryName: result.categoryName,
        price: result.price,
        description: result.description,
        stock: result.stock,
        gender: result.gender,
        season: result.season,
        time: result.time,
        occasion: result.occasion,
        intensity: result.intensity,
        fragranceFamily: result.fragranceFamily,
        topNotes: result.topNotes,
        middleNotes: result.middleNotes,
        baseNotes: result.baseNotes,
        tags: result.tags,
        imageUrls: result.imageUrls,
        size: result.size,
        salePrice: result.salePrice,
        isActive: result.isActive,
        isBestSeller: result.isBestSeller,
        isNew: result.isNew,
      );
      return entry == null
          ? cubit.createProduct(payload)
          : cubit.updateProduct(entry.id, payload);
    },
  );
}

String _formatProductPrice(double price) {
  final amount = price.toStringAsFixed(2);
  return '$amount ${AdminLocaleController.globalT('currency.symbol')}';
}

void _showBannerEditDialog(BuildContext context, BannerEntry? entry) {
  final l10n = context.read<AdminLocaleController>();
  final titleController = TextEditingController(text: entry?.title ?? '');
  final subtitleController = TextEditingController(text: entry?.mood ?? '');
  final imageController = TextEditingController(text: entry?.imageUrl ?? '');
  final targetController = TextEditingController(text: entry?.targetPath ?? '');
  var isActive = entry?.isActive ?? true;
  final cubit = context.read<AdminContentCubit>();
  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              entry == null
                  ? l10n.t('content.banner.create', fallback: 'Create Banner')
                  : l10n.t('content.banner.edit', fallback: 'Edit Banner'),
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: l10n.t(
                        'content.titleLabel',
                        fallback: 'Title',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleController,
                    decoration: InputDecoration(
                      labelText: l10n.t(
                        'content.subtitleLabel',
                        fallback: 'Subtitle',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImageSelectionField(
                    controller: imageController,
                    folder: AdminMediaFolder.banners,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    decoration: InputDecoration(
                      labelText: l10n.t(
                        'content.targetPathLabel',
                        fallback: 'Target path',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: isActive,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.t('content.active', fallback: 'Active')),
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.t('common.cancel')),
              ),
              AdminPrimaryButton(
                label: l10n.t('common.save'),
                onPressed: () {
                  final payload = AdminBannerUpsertInput(
                    title: titleController.text.trim(),
                    imageUrl: imageController.text.trim(),
                    subtitle: subtitleController.text.trim(),
                    targetPath: targetController.text.trim(),
                    isActive: isActive,
                    queuePosition: entry?.queuePosition ?? 0,
                  );
                  if (entry == null) {
                    cubit.createBanner(payload);
                  } else {
                    cubit.updateBanner(entry.id, payload);
                  }
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}

void _showCategoryEditDialog(BuildContext context, CategoryEntry? entry) {
  final l10n = context.read<AdminLocaleController>();
  final nameController = TextEditingController(text: entry?.name ?? '');
  final imageController = TextEditingController(text: entry?.imageUrl ?? '');
  final cubit = context.read<AdminContentCubit>();
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          entry == null
              ? l10n.t('content.createCategory', fallback: 'Create Category')
              : l10n.t('content.editCategory', fallback: 'Edit Category'),
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.t('content.nameLabel', fallback: 'Name'),
                ),
              ),
              const SizedBox(height: 12),
              _ImageSelectionField(
                controller: imageController,
                folder: AdminMediaFolder.categories,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          AdminPrimaryButton(
            label: l10n.t('common.save'),
            onPressed: () {
              final payload = AdminCategoryUpsertInput(
                name: nameController.text.trim(),
                imageUrl: imageController.text.trim(),
                queuePosition: entry?.queuePosition ?? 0,
                isActive: entry?.isActive ?? true,
              );
              if (entry == null) {
                cubit.createCategory(payload);
              } else {
                cubit.updateCategory(entry.id, payload);
              }
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}

class _ImageSelectionField extends StatelessWidget {
  const _ImageSelectionField({required this.controller, required this.folder});

  final TextEditingController controller;
  final AdminMediaFolder folder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<AdminLocaleController>();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final imageUrl = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('content.media.selection', fallback: 'Image Selection'),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 168,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.surfaceContainerHighest),
              ),
              child: imageUrl.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 28,
                          color: AppTheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('content.media.noneSelected', fallback: 'No image selected'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: AdminNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 10,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                AdminSecondaryButton(
                  label: imageUrl.isEmpty
                      ? l10n.t('content.media.chooseUpload', fallback: 'Choose / Upload Image')
                      : l10n.t('content.media.replace', fallback: 'Replace Image'),
                  icon: Icons.photo_library_outlined,
                  onPressed: () async {
                    final selection = await showAdminMediaPickerDialog(
                      context,
                      initialFolder: folder,
                    );
                    if (selection == null) {
                      return;
                    }
                    controller.text = selection.url;
                  },
                ),
                if (imageUrl.isNotEmpty)
                  AdminSecondaryButton(
                    label: l10n.t('content.action.clear', fallback: 'Clear'),
                    icon: Icons.close_rounded,
                    onPressed: () {
                      controller.clear();
                    },
                  ),
              ],
            ),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                imageUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurface),
              ),
            ],
          ],
        );
      },
    );
  }
}

void _moveBanner(BuildContext context, BannerEntry entry, int offset) {
  final cubit = context.read<AdminContentCubit>();
  final items = [...(cubit.state.snapshot?.banners ?? const <BannerEntry>[])];
  final current = items.indexWhere((item) => item.id == entry.id);
  final target = current + offset;
  if (current < 0 || target < 0 || target >= items.length) {
    return;
  }
  final moved = items.removeAt(current);
  items.insert(target, moved);
  cubit.reorderBanners(items.map((item) => item.id).toList());
}

void _moveCategory(BuildContext context, CategoryEntry entry, int offset) {
  final cubit = context.read<AdminContentCubit>();
  final items = [
    ...(cubit.state.snapshot?.categories ?? const <CategoryEntry>[]),
  ];
  final current = items.indexWhere((item) => item.id == entry.id);
  final target = current + offset;
  if (current < 0 || target < 0 || target >= items.length) {
    return;
  }
  final moved = items.removeAt(current);
  items.insert(target, moved);
  cubit.reorderCategories(items.map((item) => item.id).toList());
}
