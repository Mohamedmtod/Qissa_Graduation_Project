import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_inventory_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_inventory_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_inventory_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_product_editor_dialog.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminInventoryCubit(context.read<AdminInventoryRepository>())
            ..loadInventory(),
      child: const _InventoryView(),
    );
  }
}

enum _InventoryTab { overview, analytics }

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  _InventoryTab _activeTab = _InventoryTab.overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocListener<AdminInventoryCubit, AdminInventoryState>(
      listenWhen: (previous, current) =>
          previous.feedbackMessage != current.feedbackMessage &&
          current.feedbackMessage != null,
      listener: (context, state) {
        final message = state.feedbackMessage;
        if (message == null) {
          return;
        }

        AdminSnackBar.success(context, message);
        context.read<AdminInventoryCubit>().clearFeedback();
      },
      child: Column(
        children: [
          SharedTopbar(
            title: l10n.t('inventory.topbarTitle'),
            searchHint: l10n.t('inventory.searchHint'),
            tabs: [
              TopbarTab(
                label: l10n.t('common.overview'),
                active: _activeTab == _InventoryTab.overview,
                onTap: () =>
                    setState(() => _activeTab = _InventoryTab.overview),
              ),
              TopbarTab(
                label: l10n.t('common.analytics'),
                active: _activeTab == _InventoryTab.analytics,
                onTap: () =>
                    setState(() => _activeTab = _InventoryTab.analytics),
              ),
            ],
            onSearchChanged: context.read<AdminInventoryCubit>().setSearchQuery,
          ),
          Expanded(
            child: BlocBuilder<AdminInventoryCubit, AdminInventoryState>(
              builder: (context, state) {
                final snapshot = state.snapshot;
                if (state.isLoading && snapshot == null) {
                  return AdminLoadingState(
                    title: l10n.t('inventory.loadingTitle'),
                  );
                }

                if (state.loadErrorMessage != null) {
                  return AdminErrorState(
                    title: l10n.t('inventory.errorTitle'),
                    message: state.loadErrorMessage!,
                    onRetry: () =>
                        context.read<AdminInventoryCubit>().loadInventory(),
                  );
                }

                if (snapshot == null) {
                  return AdminEmptyState(
                    title: l10n.t('inventory.emptyTitle'),
                    message: l10n.t('inventory.emptyMessage'),
                    actionLabel: l10n.t('common.retry'),
                    onAction: () =>
                        context.read<AdminInventoryCubit>().loadInventory(),
                  );
                }

                if (_activeTab == _InventoryTab.analytics) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        _InventoryHealthCard(
                          healthScore: snapshot.healthScore,
                          skuCount: snapshot.skuCount,
                          lowStockCount: state.lowStockCount,
                          outOfStockCount: state.outOfStockCount,
                          overstockCount: snapshot.overstockCount,
                        ),
                        const SizedBox(height: 24),
                        _AiPredictionCard(
                          message: snapshot.aiPredictionMessage,
                          actionLabel: snapshot.aiActionLabel,
                        ),
                        const SizedBox(height: 24),
                        AdminSecondaryButton(
                          label: l10n.t('inventory.notifyMeLogs'),
                          icon: Icons.notifications_none,
                          onPressed: () => _showNotifyMeLogsDrawer(context),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
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
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AdminSectionLabel(
                                  label: l10n.t('inventory.curation'),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.t('inventory.heroTitle'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontSize: 38,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.t('inventory.heroDescription'),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              AdminSecondaryButton(
                                label: state.lowStockOnly
                                    ? l10n.t('inventory.showingLowStock')
                                    : l10n.t('inventory.allCollections'),
                                icon: Icons.tune,
                                onPressed: () => context
                                    .read<AdminInventoryCubit>()
                                    .toggleLowStockOnly(),
                              ),
                              AdminPrimaryButton(
                                label: l10n.t('inventory.addNewScent'),
                                onPressed: () => _showAddProductDialog(context),
                              ),
                              AdminSecondaryButton(
                                label: l10n.t('inventory.notifyMeLogs'),
                                icon: Icons.notifications_none,
                                onPressed: () =>
                                    _showNotifyMeLogsDrawer(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.t('inventory.fullInventory')),
                            selected: !state.lowStockOnly,
                            onSelected: (_) => context
                                .read<AdminInventoryCubit>()
                                .setLowStockOnly(false),
                          ),
                          ChoiceChip(
                            label: Text(l10n.t('inventory.lowStockFocus')),
                            selected: state.lowStockOnly,
                            onSelected: (_) => context
                                .read<AdminInventoryCubit>()
                                .setLowStockOnly(true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (state.visibleItems.isEmpty)
                        AdminEmptyState(
                          title: l10n.t('inventory.noMatchesTitle'),
                          message: l10n.t('inventory.noMatchesMessage'),
                          icon: Icons.filter_alt_off_outlined,
                          actionLabel: l10n.t('inventory.showFullInventory'),
                          onAction: () => context
                              .read<AdminInventoryCubit>()
                              .setLowStockOnly(false),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.visibleItems.length + 1,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 360,
                                mainAxisSpacing: 24,
                                crossAxisSpacing: 24,
                                childAspectRatio: 0.56,
                              ),
                          itemBuilder: (context, index) {
                            if (index == state.visibleItems.length) {
                              return _AddInventoryCard(
                                onTap: () => _showAddProductDialog(context),
                              );
                            }

                            final item = state.visibleItems[index];
                            return _InventoryCard(item: item);
                          },
                        ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 1100;

                          if (stacked) {
                            return Column(
                              children: [
                                _InventoryHealthCard(
                                  healthScore: snapshot.healthScore,
                                  skuCount: snapshot.skuCount,
                                  lowStockCount: state.lowStockCount,
                                  outOfStockCount: state.outOfStockCount,
                                  overstockCount: snapshot.overstockCount,
                                ),
                                const SizedBox(height: 24),
                                _AiPredictionCard(
                                  message: snapshot.aiPredictionMessage,
                                  actionLabel: snapshot.aiActionLabel,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                flex: 8,
                                child: _InventoryHealthCard(
                                  healthScore: snapshot.healthScore,
                                  skuCount: snapshot.skuCount,
                                  lowStockCount: state.lowStockCount,
                                  outOfStockCount: state.outOfStockCount,
                                  overstockCount: snapshot.overstockCount,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 4,
                                child: _AiPredictionCard(
                                  message: snapshot.aiPredictionMessage,
                                  actionLabel: snapshot.aiActionLabel,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final pillBg = item.lowStock
        ? AppTheme.secondaryContainer
        : Colors.white.withValues(alpha: 0.85);
    final pillFg = item.lowStock ? Colors.white : AppTheme.tertiary;

    return AdminSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: item.lowStock
          ? AppTheme.surfaceContainerLowest.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.42),
      border: item.lowStock
          ? Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.16),
              width: 2,
            )
          : null,
      shadow: item.lowStock
          ? [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ]
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AdminNetworkImage(
                imageUrl: item.imageUrl,
                width: double.infinity,
                height: 220,
                borderRadius: 20,
              ),
              Positioned(
                top: 14,
                right: 14,
                child: AdminPill(
                  label: item.lowStock
                      ? l10n.t('inventory.lowStockBadge', fallback: 'Low stock')
                      : l10n.t('inventory.inStockBadge', fallback: 'In stock'),
                  backgroundColor: pillBg,
                  foregroundColor: pillFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Expanded makes the Column below bounded, so Spacer() works correctly.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + units row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: AppTheme.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _resolveCollectionLabel(l10n, item.collection),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.units}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: item.lowStock
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
                              ),
                        ),
                        Text(
                          item.lowStock
                              ? l10n.t('inventory.unitsLeft', fallback: 'left')
                              : l10n.t(
                                  'inventory.unitsAvailable',
                                  fallback: 'available',
                                ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: item.lowStock
                                    ? AppTheme.secondary
                                    : AppTheme.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Spacer pushes the action bar to the bottom of the Expanded space.
                const Spacer(),
                Divider(color: AppTheme.outlineVariant.withValues(alpha: 0.25)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AdminPrimaryButton(
                    label: l10n.t(
                      'inventory.restockNow',
                      fallback: 'Restock now',
                    ),
                    onPressed: () => _showRestockDialog(context, item),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.lowStock)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _trendIcon(item.trend),
                              size: 18,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.t(
                                  'inventory.usersWaiting',
                                  fallback: 'users waiting',
                                ),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                    TextButton(
                      onPressed: () =>
                          _showInventoryDetailsSheet(context, item),
                      child: Text(
                        l10n.t('inventory.details', fallback: 'Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddInventoryCard extends StatelessWidget {
  const _AddInventoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppTheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.t('inventory.archiveNewEssence'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primary,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    l10n.t('inventory.archiveDescription'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryHealthCard extends StatelessWidget {
  const _InventoryHealthCard({
    required this.healthScore,
    required this.skuCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.overstockCount,
  });

  final double healthScore;
  final int skuCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int overstockCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      color: AppTheme.surfaceContainerLow,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 18,
        spacing: 18,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminSectionLabel(label: l10n.t('inventory.healthTitle')),
              const SizedBox(height: 10),
              Text(
                '${healthScore.toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('inventory.healthSubtitle'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          Wrap(
            spacing: 36,
            runSpacing: 16,
            children: [
              _InventoryMiniStat(
                label: l10n.t('inventory.lowStock'),
                value: '$lowStockCount',
                kind: _InventoryStatKind.low,
              ),
              _InventoryMiniStat(
                label: l10n.t('inventory.outOfStock'),
                value: '$outOfStockCount',
                kind: _InventoryStatKind.out,
              ),
              _InventoryMiniStat(
                label: l10n.t('inventory.overstock'),
                value: '$overstockCount',
                kind: _InventoryStatKind.over,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _InventoryStatKind { low, out, over }

class _InventoryMiniStat extends StatelessWidget {
  const _InventoryMiniStat({
    required this.label,
    required this.value,
    required this.kind,
  });

  final String label;
  final String value;
  final _InventoryStatKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: kind == _InventoryStatKind.low
                ? AppTheme.secondary
                : kind == _InventoryStatKind.out
                ? const Color(0xFFBA1A1A)
                : AppTheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _AiPredictionCard extends StatelessWidget {
  const _AiPredictionCard({required this.message, required this.actionLabel});

  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return AdminSurfaceCard(
      padding: const EdgeInsets.all(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.primary, Color(0xFF401118)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: AppTheme.primaryFixed,
              ),
              const Spacer(),
              AdminPill(
                label: l10n.t('inventory.aiPrediction'),
                backgroundColor: const Color(0x33FFD9DD),
                foregroundColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () =>
                _showInventoryActionStrategySheet(context, message),
            child: Text(
              actionLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.primaryFixed),
            ),
          ),
        ],
      ),
    );
  }
}

void _showInventoryDetailsSheet(BuildContext context, InventoryItem item) {
  final l10n = context.read<AdminLocaleController>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(_resolveCollectionLabel(l10n, item.collection)),
              const SizedBox(height: 12),
              Text('${l10n.t('inventory.unitsAvailable')}: ${item.units}'),
              Text('${l10n.t('inventory.usersWaiting')}: ${item.waitingUsers}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  AdminSecondaryButton(
                    label: l10n.t('inventory.restockNow'),
                    icon: Icons.inventory_2_outlined,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showRestockDialog(context, item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showInventoryActionStrategySheet(BuildContext context, String message) {
  final l10n = context.read<AdminLocaleController>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('inventory.aiPrediction'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 10),
              Text(message),
              const SizedBox(height: 12),
              Text(l10n.t('inventory.strategy.lowStock', fallback: '1. Prioritize top low-stock SKUs.')),
              Text(l10n.t('inventory.strategy.highDemand', fallback: '2. Trigger restock for high-demand items.')),
              Text(l10n.t('inventory.strategy.reviewQueue', fallback: '3. Review notify-me queue before peak hours.')),
            ],
          ),
        ),
      );
    },
  );
}

IconData _trendIcon(InventoryTrend trend) {
  return switch (trend) {
    InventoryTrend.up => Icons.trending_up,
    InventoryTrend.down => Icons.trending_down,
    InventoryTrend.surge => Icons.bolt,
  };
}

String _resolveCollectionLabel(AdminLocaleController l10n, String rawValue) {
  final normalized = rawValue.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'unknown' ||
      normalized == 'uncategorized') {
    return l10n.t('inventory.collection.uncategorized');
  }

  if (normalized == 'perfumes' || normalized == 'perfume') {
    return l10n.t('inventory.collection.perfumes');
  }

  return l10n.resolve(rawValue);
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}

void _showRestockDialog(BuildContext context, InventoryItem item) {
  final l10n = context.read<AdminLocaleController>();
  final controller = TextEditingController(text: '${item.units}');
  final cubit = context.read<AdminInventoryCubit>();
  final formKey = GlobalKey<FormState>();

  void submitAdjustment(BuildContext dialogContext) {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    final targetStock = int.parse(controller.text.trim());
    final quantityDelta = targetStock - item.units;
    if (quantityDelta == 0) {
      _showMessage(dialogContext, l10n.t('inventory.noStockChange'));
      return;
    }

    cubit.executeRestock(item, quantityDelta);
    Navigator.of(dialogContext).pop();
  }

  void incrementStock() {
    final current = int.tryParse(controller.text.trim()) ?? item.units;
    controller.text = '${current + 1}';
  }

  void decrementStock() {
    final current = int.tryParse(controller.text.trim()) ?? item.units;
    if (current <= 0) {
      return;
    }
    controller.text = '${current - 1}';
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          l10n.t('inventory.restockTitle', params: {'name': item.name}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('inventory.enterUnits')),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: Row(
                children: [
                  IconButton(
                    onPressed: decrementStock,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: l10n.t('inventory.decrementStock'),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: l10n.t('inventory.currentStockLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null) {
                          return l10n.t('inventory.invalidStockAmount');
                        }
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: incrementStock,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: l10n.t('inventory.incrementStock'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.cancel')),
          ),
          AdminPrimaryButton(
            label: l10n.t('inventory.confirmStockUpdate'),
            onPressed: () {
              submitAdjustment(dialogContext);
            },
          ),
        ],
      );
    },
  );
}

void _showAddProductDialog(BuildContext context) {
  final l10n = context.read<AdminLocaleController>();
  final cubit = context.read<AdminInventoryCubit>();
  showAdminProductEditorDialog(
    context,
    title: l10n.t('inventory.addProductDialogTitle'),
    onSubmit: (result) async {
      await cubit.createInventoryItem(
        name: result.name,
        nameAr: result.nameAr,
        brand: result.brand,
        brandAr: result.brandAr,
        aliases: result.aliases,
        aliasesAr: result.aliasesAr,
        description: result.description,
        price: result.price,
        size: result.size,
        salePrice: result.salePrice,
        collection: result.categoryName,
        stock: result.stock,
        isBestSeller: result.isBestSeller,
        isNew: result.isNew,
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
        productType: result.productType,
        isSellable: result.isSellable,
        unitType: result.unitType,
        variants: result.variants,
        staffTagScores: result.staffTagScores,
        staffWarnings: result.staffWarnings,
        staffSalesNotes: result.staffSalesNotes,
        similarFamousDna: result.similarFamousDna,
        staffIntelligenceStatus: result.staffIntelligenceStatus,
        reviewNeeded: result.reviewNeeded,
        staffConfidence: result.staffConfidence,
        staffDataCoverage: result.staffDataCoverage,
        staffTaxonomyVersion: result.staffTaxonomyVersion,
      );
      return true;
    },
  );
}

void _showNotifyMeLogsDrawer(BuildContext context) {
  final l10n = context.read<AdminLocaleController>();
  context.read<AdminInventoryCubit>().loadRestockLogs();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.t('common.dismiss'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: 450,
            height: double.infinity,
            child: _NotifyMeLogsView(parentContext: context),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _NotifyMeLogsView extends StatelessWidget {
  const _NotifyMeLogsView({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocProvider.value(
      value: parentContext.read<AdminInventoryCubit>(),
      child: BlocBuilder<AdminInventoryCubit, AdminInventoryState>(
        builder: (context, state) {
          final logs = state.restockLogs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.t('inventory.demandLogs'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppTheme.primary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: logs == null
                    ? const Center(child: CircularProgressIndicator())
                    : logs.isEmpty
                    ? AdminEmptyState(
                        title: l10n.t('inventory.noPendingDemands'),
                        message: l10n.t('inventory.noPendingDemandsMessage'),
                      )
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          // Find matching inventory item to allow quick restock
                          final matchedItem = state.items.firstWhere(
                            (item) => item.name == log.itemName,
                            orElse: () => InventoryItem(
                              id: 'missing_${log.itemName}',
                              name: log.itemName,
                              collection: 'Unknown',
                              imageUrl: '',
                              units: 0,
                              waitingUsers: log.requestedUnits,
                              trend: InventoryTrend.surge,
                            ),
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            title: Text(
                              log.itemName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(l10n.t('inventory.sinceDate')),
                                const SizedBox(height: 4),
                                AdminPill(
                                  label: l10n.t('inventory.requestsCount'),
                                  backgroundColor: AppTheme.secondaryContainer,
                                  foregroundColor: Colors.white,
                                ),
                              ],
                            ),
                            trailing: AdminPrimaryButton(
                              label: l10n.t('inventory.restock'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showRestockDialog(parentContext, matchedItem);
                              },
                            ),
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
}
