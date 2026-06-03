import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_order.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_orders_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_orders_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/utils/admin_export_utils.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminOrdersCubit(context.read<AdminOrdersRepository>())..loadOrders(),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocConsumer<AdminOrdersCubit, AdminOrdersState>(
      listener: (context, state) {
        final message = state.feedbackMessage;
        if (message == null || message.isEmpty) {
          return;
        }

        AdminSnackBar.show(
          context,
          message: message,
          tone: state.feedbackIsError
              ? AdminSnackBarTone.error
              : AdminSnackBarTone.success,
        );
        context.read<AdminOrdersCubit>().dismissFeedback();
      },
      builder: (context, state) {
        return Column(
          children: [
            SharedTopbar(
              title: l10n.t('orders.topbarTitle'),
              searchHint: l10n.t('orders.searchHint'),
              tabs: [
                TopbarTab(label: l10n.t('common.overview'), active: true),
                TopbarTab(label: l10n.t('common.analytics')),
              ],
              onSearchChanged: context.read<AdminOrdersCubit>().setSearchQuery,
            ),
            Expanded(
              child: state.isLoading
                  ? AdminLoadingState(title: l10n.t('orders.loadingTitle'))
                  : state.loadErrorMessage != null
                  ? AdminErrorState(
                      title: l10n.t('orders.errorTitle'),
                      message: state.loadErrorMessage!,
                      onRetry: () =>
                          context.read<AdminOrdersCubit>().loadOrders(),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OrdersHeader(state: state),
                          const SizedBox(height: 28),
                          _OrdersFilters(state: state),
                          const SizedBox(height: 28),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1380;

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: _OrdersList(state: state),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 5,
                                      child: _OrderDetailsPanel(
                                        order: state.selectedOrder,
                                        isTransitioning: state.isTransitioning,
                                        transitionTargetStatus:
                                            state.transitionTargetStatus,
                                        transitionOrderId:
                                            state.transitionOrderId,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _OrdersList(state: state),
                                  const SizedBox(height: 24),
                                  _OrderDetailsPanel(
                                    order: state.selectedOrder,
                                    isTransitioning: state.isTransitioning,
                                    transitionTargetStatus:
                                        state.transitionTargetStatus,
                                    transitionOrderId: state.transitionOrderId,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({required this.state});

  final AdminOrdersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 18,
      spacing: 18,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('orders.headerTitle'),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppTheme.primary,
                fontSize: 40,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                l10n.t('orders.headerDescription'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminSecondaryButton(
              label:
                  '${state.visibleOrders.length} ${l10n.t('orders.visibleCount')}',
              icon: Icons.inventory_2_outlined,
              onPressed: null,
            ),
            AdminPrimaryButton(
              label: l10n.t('orders.exportLedger'),
              onPressed: state.visibleOrders.isEmpty
                  ? null
                  : () async {
                      final exported = await _exportOrderLedgerCsv(
                        state.visibleOrders,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _showMessage(
                        context,
                        exported
                            ? l10n.t('orders.exportLedgerSuccess')
                            : l10n.t('orders.exportLedgerCancelled'),
                      );
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _OrdersFilters extends StatelessWidget {
  const _OrdersFilters({required this.state});

  final AdminOrdersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final cubit = context.read<AdminOrdersCubit>();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: cubit.setSearchQuery,
            decoration: InputDecoration(
              hintText: l10n.t('orders.filterHint'),
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        _FilterChip(
          label: l10n.t('orders.allStatuses'),
          selected: state.statusFilter == null,
          onTap: () => cubit.setStatusFilter(null),
        ),
        ...AdminOrderStatus.values.map(
          (status) => _FilterChip(
            label: adminOrderStatusLabel(status),
            selected: state.statusFilter == status,
            onTap: () => cubit.setStatusFilter(status),
          ),
        ),
        PopupMenuButton<AdminOrderDateFilter>(
          tooltip: l10n.t('orders.dateFilterTooltip'),
          onSelected: cubit.setDateFilter,
          itemBuilder: (context) => AdminOrderDateFilter.values
              .map(
                (filter) => PopupMenuItem(
                  value: filter,
                  child: Text(adminOrderDateFilterLabel(filter)),
                ),
              )
              .toList(),
          child: AdminSecondaryButton(
            label: adminOrderDateFilterLabel(state.dateFilter),
            icon: Icons.calendar_today_outlined,
            onPressed: null,
          ),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.state});

  final AdminOrdersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final visible = state.visibleOrders;
    final paged = state.pagedOrders;
    if (visible.isEmpty) {
      return AdminEmptyState(
        title: l10n.t('orders.noMatchTitle'),
        message: l10n.t('orders.noMatchMessage'),
        icon: Icons.receipt_long_outlined,
        actionLabel: l10n.t('orders.clearFilters'),
        onAction: () => context.read<AdminOrdersCubit>().clearFilters(),
      );
    }

    final totalVolume = visible.fold<int>(
      0,
      (sum, order) => sum + order.totalAmount,
    );

    return Column(
      children: [
        ...paged.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _OrderCard(
              order: order,
              isSelected: order.id == state.selectedOrderId,
            ),
          ),
        ),
        AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          color: AppTheme.surfaceContainer,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 16,
            spacing: 16,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _SummaryBadge(
                    label: l10n.t('orders.totalVisible'),
                    value: formatMoney(totalVolume),
                  ),
                  _SummaryBadge(
                    label: l10n.t('orders.ordersCount'),
                    value: '${visible.length}',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  _PageDotButton(
                    icon: Icons.chevron_left,
                    active: false,
                    enabled: state.canGoPrevious,
                    onTap: () {
                      context.read<AdminOrdersCubit>().previousPage();
                    },
                  ),
                  _PageDotButton(
                    label: '${state.normalizedCurrentPage}',
                    active: true,
                    onTap: () {},
                  ),
                  _PageDotButton(
                    icon: Icons.chevron_right,
                    active: false,
                    enabled: state.canGoNext,
                    onTap: () {
                      context.read<AdminOrdersCubit>().nextPage();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.isSelected});

  final AdminOrder order;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final statusColors = _statusColors(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.read<AdminOrdersCubit>().selectOrder(order.id),
        child: AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          border: isSelected
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.18))
              : null,
          color: isSelected
              ? Colors.white.withValues(alpha: 0.98)
              : AppTheme.surfaceContainerLowest.withValues(alpha: 0.9),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrderIdentity(order: order),
                    const SizedBox(height: 20),
                    _OrderProducts(products: order.products),
                    const SizedBox(height: 20),
                    _OrderFooter(order: order, statusColors: statusColors),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 2, child: _OrderIdentity(order: order)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: _OrderProducts(products: order.products),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _OrderFooter(
                      order: order,
                      statusColors: statusColors,
                      alignEnd: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrderIdentity extends StatelessWidget {
  const _OrderIdentity({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(width: 72, height: 72),
            Positioned(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x14000000), blurRadius: 10),
                  ],
                ),
                child: AdminNetworkImage(
                  imageUrl: order.customer.avatarUrl,
                  width: 64,
                  height: 64,
                  borderRadius: 999,
                ),
              ),
            ),
            if (order.customer.verified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 16,
                    color: AppTheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t(
                  'orders.orderNumber',
                  fallback: 'Order #{id}',
                  params: {'id': order.id},
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.customer.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(order.location),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderProducts extends StatelessWidget {
  const _OrderProducts({required this.products});

  final List<AdminOrderProduct> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Stack(
        children: [
          for (var i = 0; i < products.length; i++)
            Positioned(
              left: i * 54,
              child: Stack(
                children: [
                  AdminNetworkImage(
                    imageUrl: products[i].imageUrl,
                    width: 88,
                    height: 104,
                    borderRadius: 16,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderFooter extends StatelessWidget {
  const _OrderFooter({
    required this.order,
    required this.statusColors,
    this.alignEnd = false,
  });

  final AdminOrder order;
  final ({Color background, Color foreground}) statusColors;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          order.formattedTotal,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.primary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _localizePaymentMethod(order.paymentMethod, l10n),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminPill(
              label: adminOrderStatusLabel(order.status),
              backgroundColor: statusColors.background,
              foregroundColor: statusColors.foreground,
            ),
            TextButton(
              onPressed: () =>
                  context.read<AdminOrdersCubit>().selectOrder(order.id),
              child: Text(l10n.t('orders.openDetails')),
            ),
          ],
        ),
      ],
    );
  }

  String _localizePaymentMethod(String method, AdminLocaleController l10n) {
    switch (method.toLowerCase()) {
      case 'cash_on_delivery':
      case 'cod':
        return l10n.t('orders.payment.cod', fallback: 'الدفع عند الاستلام');
      case 'card':
      case 'credit_card':
      case 'stripe':
        return l10n.t('orders.payment.card', fallback: 'بطاقة الائتمان');
      default:
        return method;
    }
}
}

class _OrderDetailsPanel extends StatelessWidget {
  const _OrderDetailsPanel({
    required this.order,
    required this.isTransitioning,
    required this.transitionTargetStatus,
    required this.transitionOrderId,
  });

  final AdminOrder? order;
  final bool isTransitioning;
  final AdminOrderStatus? transitionTargetStatus;
  final String? transitionOrderId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    if (order == null) {
      return AdminEmptyState(
        title: l10n.t('orders.noSelectionTitle'),
        message: l10n.t('orders.noSelectionMessage'),
        icon: Icons.touch_app_outlined,
      );
    }

    final currentOrder = order!;
    final isActiveTransition =
        isTransitioning && transitionOrderId == currentOrder.id;

    return Column(
      children: [
        AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t(
                            'orders.details.orderTitle',
                            params: {
                              'id': currentOrder.id.contains('-') 
                                  ? currentOrder.id.split('-').first.toUpperCase() 
                                  : (currentOrder.id.length > 8 ? currentOrder.id.substring(0, 8).toUpperCase() : currentOrder.id.toUpperCase())
                            },
                          ),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppTheme.primary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t(
                            'orders.details.createdAt',
                            params: {
                              'date': formatTimelineDate(
                                currentOrder.createdAt,
                              ),
                            },
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  AdminPill(
                    label: adminOrderStatusLabel(currentOrder.status),
                    backgroundColor: _statusColors(
                      currentOrder.status,
                    ).background,
                    foregroundColor: _statusColors(
                      currentOrder.status,
                    ).foreground,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DetailsInfoRow(
                label: l10n.t('orders.customer'),
                value:
                    '${currentOrder.customer.name}\n${currentOrder.customer.email}\n${currentOrder.customer.phone}',
              ),
              _DetailsInfoRow(
                label: l10n.t('orders.shipping'),
                value:
                    '${currentOrder.address.recipient}\n${currentOrder.address.formatted}',
              ),
              _DetailsInfoRow(
                label: l10n.t('orders.payment'),
                value: l10n.t(
                  'orders.details.paymentSummary',
                  params: {
                    'method': currentOrder.paymentMethod,
                    'total': currentOrder.formattedTotal,
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          color: AppTheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('orders.details.statusActionsTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('orders.details.statusActionsDescription'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AdminOrderStatus.values.map((status) {
                  final active = currentOrder.status == status;
                  final busyForThisStatus =
                      isActiveTransition && transitionTargetStatus == status;
                  return _StatusActionButton(
                    label: adminOrderStatusLabel(status),
                    active: active,
                    isBusy: busyForThisStatus,
                    enabled: !isTransitioning,
                    onTap: () => context
                        .read<AdminOrdersCubit>()
                        .attemptTransition(status),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('orders.details.itemsTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 18),
              ...currentOrder.products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      AdminNetworkImage(
                        imageUrl: product.imageUrl,
                        width: 64,
                        height: 72,
                        borderRadius: 14,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppTheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${l10n.t('orders.skuLabel')}: ${product.sku}',
                            ),
                            Text(
                              '${l10n.t('orders.quantityLabel')}: ${product.quantity}',
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatMoney(product.subtotal),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AdminSurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('orders.details.timelineTitle'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 18),
              ...currentOrder.timeline.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.note,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppTheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${adminTimelineActorRoleLabel(entry.actorRole)} (${entry.actorId})',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              adminTimelineSourceLabel(entry.source),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatTimelineDate(entry.occurredAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (entry.fromStatus != null &&
                                entry.toStatus != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.t(
                                  'orders.timeline.fromTo',
                                  params: {
                                    'from': adminOrderStatusLabel(
                                      entry.fromStatus!,
                                    ),
                                    'to': adminOrderStatusLabel(
                                      entry.toStatus!,
                                    ),
                                  },
                                ),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppTheme.secondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsInfoRow extends StatelessWidget {
  const _DetailsInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.active,
    required this.isBusy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool isBusy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppTheme.primary
          : AppTheme.surfaceContainerHighest.withValues(
              alpha: enabled ? 1 : 0.65,
            ),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? Colors.white : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      borderRadius: 18,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _PageDotButton extends StatelessWidget {
  const _PageDotButton({
    this.label,
    this.icon,
    required this.active,
    this.enabled = true,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppTheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: active
                        ? Colors.white
                        : enabled
                        ? AppTheme.onSurfaceVariant
                        : AppTheme.onSurfaceVariant.withValues(alpha: 0.36),
                  )
                : Text(
                    label ?? '',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active
                          ? Colors.white
                          : enabled
                          ? AppTheme.onSurfaceVariant
                          : AppTheme.onSurfaceVariant.withValues(alpha: 0.36),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

({Color background, Color foreground}) _statusColors(AdminOrderStatus status) {
  return switch (status) {
    AdminOrderStatus.orderProcessing => (
      background: const Color(0xFFE8F4FD),
      foreground: const Color(0xFF0265D2),
    ),
    AdminOrderStatus.outForDelivery => (
      background: const Color(0xFFE3F2FD),
      foreground: const Color(0xFF1565C0),
    ),
    AdminOrderStatus.pending => (
      background: const Color(0xFFFFF4E5),
      foreground: const Color(0xFFB06000),
    ),
    AdminOrderStatus.delivered => (
      background: const Color(0xFFE6F4EA),
      foreground: const Color(0xFF0D652D),
    ),
    AdminOrderStatus.cancelled => (
      background: const Color(0xFFFCE8E6),
      foreground: const Color(0xFFC5221F),
    ),
  };
}

void _showMessage(BuildContext context, String message) {
  AdminSnackBar.info(context, message);
}

Future<bool> _exportOrderLedgerCsv(List<AdminOrder> orders) {
  final now = DateTime.now();
  final csv = buildCsv([
    [
      'orderId',
      'customer',
      'email',
      'phone',
      'status',
      'total',
      'paymentMethod',
      'location',
      'createdAt',
      'items',
    ],
    ...orders.map(
      (order) => [
        order.id,
        order.customer.name,
        order.customer.email,
        order.customer.phone,
        orderStatusToFirestore(order.status),
        order.totalAmount / 100,
        order.paymentMethod,
        order.location,
        order.createdAt.toIso8601String(),
        order.products
            .map((product) => '${product.name} x${product.quantity}')
            .join(' | '),
      ],
    ),
  ]);
  return saveTextFile(
    dialogTitle: 'Save order ledger',
    fileName: 'orders-ledger-${now.year}-${now.month}-${now.day}.csv',
    extension: 'csv',
    content: csv,
  );
}
