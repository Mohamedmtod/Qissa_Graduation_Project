import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';

import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/features/orders/presentation/manager/orders_cubit.dart';
import 'package:perfume_app/features/orders/data/models/order_model.dart';
import 'package:perfume_app/features/orders/utils/order_display_code.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';
import 'package:perfume_app/widgets/custom_empty_state.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _cancellingOrderIds = <String>{};
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  void _onScroll() {
    final state = context.read<OrdersCubit>().state;
    if (state is! OrdersLoaded || !state.hasMore) return;

    final pos = _scrollController.position;
    if (pos.pixels > 0 && pos.pixels >= pos.maxScrollExtent - 80) {
      context.read<OrdersCubit>().loadMore();
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    if (_cancellingOrderIds.contains(order.id)) return;
    final ordersCubit = context.read<OrdersCubit>();

    final l10n = AppLocalizations.of(context);
    final shouldCancel =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.msgCancelOrderTitle),
            content: Text(l10n.msgCancelOrderDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.btnNo),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.btnYesCancel),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldCancel) return;

    setState(() {
      _cancellingOrderIds.add(order.id);
    });

    try {
      await ordersCubit.cancelPendingOrder(order.id);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        l10n.msgOrderCancelledSuccess(
          orderDisplayCode(orderId: order.id, orderCode: order.orderCode),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        resolveUserFacingMessage(
          context,
          error,
          fallback: l10n.msgOrderPlaceFailed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrderIds.remove(order.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: CustomTextStyle(
          text: AppLocalizations.of(context).labelMyOrders,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            if (state is OrdersLoading || state is OrdersInitial) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: OrderListSkeleton(itemCount: 4),
              );
            }
            if (state is OrdersError) {
              return _buildErrorState(
                context,
                resolveUserFacingMessage(
                  context,
                  state.message,
                  fallback: AppLocalizations.of(
                    context,
                  ).msgOrderLoadFailed,
                ),
                AppLocalizations.of(context),
              );
            }
            if (state is OrdersEmpty) {
              return _buildEmptyState(AppLocalizations.of(context));
            }
            if (state is OrdersLoadingMore) {
              return _buildOrdersList(
                state.currentOrders,
                hasMore: true,
                isLoadingMore: true,
              );
            }
            if (state is OrdersLoaded) {
              return _buildOrdersList(
                state.orders,
                hasMore: state.hasMore,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Empty State
  // ──────────────────────────────────────────────
  Widget _buildEmptyState(AppLocalizations l10n) {
    return FadeTransition(
      opacity: _fadeController,
      child: CustomEmptyState(
        icon: Icons.receipt_long_outlined,
        message: l10n.msgNoOrdersYet,
        subtitle: l10n.msgStartShoppingOrders,
        onRetry: navigateToMainLayout(context, Go.home),
        actionLabel: l10n.btnBrowseProducts,
        actionIcon: Icons.shopping_bag_outlined,
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Error State
  // ──────────────────────────────────────────────
  Widget _buildErrorState(
    BuildContext context,
    String message,
    AppLocalizations l10n,
  ) {
    return FadeTransition(
      opacity: _fadeController,
      child: CustomEmptyState(
        icon: Icons.wifi_off_rounded,
        message: l10n.msgSomethingWentWrong,
        subtitle: message,
        onRetry: () => context.read<OrdersCubit>().loadOrders(),
        actionLabel: l10n.btnTryAgain,
        actionIcon: Icons.refresh_rounded,
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  Orders List
  // ──────────────────────────────────────────────
  Widget _buildOrdersList(
    List<OrderModel> orders, {
    bool hasMore = false,
    bool isLoadingMore = false,
  }) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: orders.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 24),
              child: OrderCardSkeleton(),
            );
          }
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 80)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _OrderCard(
              order: orders[index],
              isCancelling: _cancellingOrderIds.contains(orders[index].id),
              onCancel: () => _cancelOrder(orders[index]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  Order Card — Modern Design
// ─────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isCancelling;
  final VoidCallback? onCancel;

  const _OrderCard({
    required this.order,
    this.isCancelling = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr = _formatDate(order.createdAt);
    final displayCode = orderDisplayCode(
      orderId: order.id,
      orderCode: order.orderCode,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          // ── Leading Icon ──
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),

          // ── Title ──
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextStyle(
                      text: l10n.labelOrderNumber(displayCode),
                      fontsize: 15,
                      bold: true,
                      textColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: lightGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: CustomTextStyle(
                            text: dateStr,
                            fontsize: 11,
                            bold: false,
                            textColor: lightGray,
                            maxLines: 1,
                            textOverflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),

          // ── Expanded Content ──
          children: [
            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lighterBeige2.withValues(alpha: 0),
                    lighterBeige2,
                    lighterBeige2.withValues(alpha: 0),
                  ],
                ),
              ),
            ),

            // ── Items ──
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: lighterBeige22,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: CustomTextStyle(
                          text: l10n.labelQuantityFormat(item.quantity),
                          fontsize: 12,
                          bold: true,
                          textColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextStyle(
                        text: item.name,
                        fontsize: 14,
                        bold: false,
                        textColor: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    CustomTextStyle(
                      text: l10n.labelPrice(
                        item.priceSnapshot.toStringAsFixed(0),
                      ),
                      fontsize: 13,
                      bold: true,
                      textColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Divider ──
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lighterBeige2.withValues(alpha: 0),
                    lighterBeige2,
                    lighterBeige2.withValues(alpha: 0),
                  ],
                ),
              ),
            ),

            // ── Info Row: Address + Phone + Payment ──
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: order.address.isNotEmpty ? order.address : l10n.labelNA,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              text: order.phone.isNotEmpty ? order.phone : l10n.labelNA,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.payment_outlined,
              text: _paymentMethodLabel(context, order.paymentMethod),
            ),

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.sticky_note_2_outlined, text: order.notes!),
            ],

            if (order.status.toLowerCase() == 'cancelled' &&
                order.failureReason != null &&
                order.failureReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.error_outline_rounded,
                text: l10n.labelReason(order.failureReason!),
                iconColor: Colors.redAccent,
                textColor: Colors.redAccent,
              ),
            ],

            const SizedBox(height: 16),

            // ── Total ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: lighterBeige22,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomTextStyle(
                    text: l10n.labelTotal,
                    fontsize: 15,
                    bold: false,
                    textColor: darkGray,
                  ),
                  CustomTextStyle(
                    text: l10n.labelPrice(order.total.toStringAsFixed(2)),
                    fontsize: 18,
                    bold: true,
                    textColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),

            if (order.status.toLowerCase() == 'pending' &&
                onCancel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  onPressed: isCancelling ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isCancelling
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red.shade400,
                          ),
                        )
                      : Text(
                          l10n.btnCancelOrder,
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(Timestamp ts) {
    final dt = ts.toDate();
    // Use intl for localized date formatting
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  String _paymentMethodLabel(BuildContext context, String paymentMethod) {
    final l10n = AppLocalizations.of(context);
    final normalized = paymentMethod.trim().toLowerCase();

    if (normalized == PaymentMethodCodes.cashOnDelivery ||
        normalized == 'cash on delivery') {
      return l10n.labelCashOnDelivery;
    }

    if (normalized == PaymentMethodCodes.card || normalized == 'card') {
      return l10n.labelDebitCreditCard;
    }

    return paymentMethod;
  }
}

// ─────────────────────────────────────────────────
//  Info Row — for address, phone, payment
// ─────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;
  const _InfoRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor != null
                ? iconColor!.withValues(alpha: 0.1)
                : lighterBeige22,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor ?? Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CustomTextStyle(
              text: text,
              fontsize: 13,
              bold: false,
              textColor: textColor ?? darkGray,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
//  Status Chip — Modern with subtle icon
// ─────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (Color bg, Color fg, IconData icon, String label) = switch (status
        .toLowerCase()) {
      'pending' => (
        const Color(0xFFFFF8E1),
        const Color(0xFFE65100),
        Icons.schedule_rounded,
        l10n.labelStatusPending,
      ),
      'order_processing' => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        Icons.inventory_2_outlined,
        l10n.labelStatusOrderProcessing,
      ),
      'out_for_delivery' => (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        Icons.local_shipping_outlined,
        l10n.labelStatusOutForDelivery,
      ),
      'confirmed' => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        Icons.check_circle_outline_rounded,
        l10n.labelStatusOrderProcessing,
      ),
      'delivered' => (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        Icons.local_shipping_outlined,
        l10n.labelStatusDelivered,
      ),
      'cancelled' => (
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
        Icons.cancel_outlined,
        l10n.labelStatusCancelled,
      ),
      _ => (
        Colors.grey.shade100,
        Colors.grey.shade600,
        Icons.info_outline_rounded,
        status,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
