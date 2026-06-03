import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/features/ai_chat/data/models/restock_request_model.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/profile/data/repos/restock_requests_repo.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class MyRestockRequestsPage extends StatefulWidget {
  const MyRestockRequestsPage({super.key});

  @override
  State<MyRestockRequestsPage> createState() => _MyRestockRequestsPageState();
}

class _MyRestockRequestsPageState extends State<MyRestockRequestsPage> {
  final RestockRequestsRepo _repo = RestockRequestsRepo();
  final Set<String> _cancellingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.labelAvailabilityRequests),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: userId.isEmpty
          ? _InfoState(
              icon: Icons.lock_outline,
              title: l10n.msgPleaseLogInFirst,
              subtitle: l10n.msgNeedAccountToTrack,
            )
          : StreamBuilder<List<RestockRequestModel>>(
              stream: _repo.watchMyRequests(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: OrderListSkeleton(itemCount: 3),
                  );
                }

                if (snapshot.hasError) {
                  return _InfoState(
                    icon: Icons.error_outline,
                    title: l10n.msgCouldNotLoadRequests,
                    subtitle: l10n.msgPleaseTryAgain,
                  );
                }

                final requests = snapshot.data ?? const <RestockRequestModel>[];
                if (requests.isEmpty) {
                  return _InfoState(
                    icon: Icons.notifications_none,
                    title: l10n.msgNoAvailabilityRequests,
                    subtitle: l10n.msgUseNotifyMeButton,
                  );
                }

                final productIds = requests.map((r) => r.productId).toSet();
                return FutureBuilder<Map<String, String>>(
                  future: _repo.fetchProductNamesByIds(productIds),
                  builder: (context, namesSnapshot) {
                    final names =
                        namesSnapshot.data ?? const <String, String>{};
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: requests.length + 1,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _RequestsHeader(
                            count: requests.length,
                            isLoadingNames:
                                namesSnapshot.connectionState ==
                                ConnectionState.waiting,
                          );
                        }

                        final request = requests[index - 1];
                        return _RestockRequestCard(
                          request: request,
                          productName:
                              names[request.productId] ?? request.productId,
                          isCancelling: _cancellingIds.contains(request.id),
                          onCancel: () =>
                              _cancelRequest(userId: userId, request: request),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _cancelRequest({
    required String userId,
    required RestockRequestModel request,
  }) async {
    setState(() {
      _cancellingIds.add(request.id);
    });

    try {
      await _repo.cancelRequest(userId: userId, request: request);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.showSuccess(context, l10n.msgRequestCancelled);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.showError(
        context,
        resolveUserFacingMessage(
          context,
          e,
          fallback: l10n.msgCancelRequestFailedGeneric,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingIds.remove(request.id);
        });
      }
    }
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader({required this.count, required this.isLoadingNames});

  final int count;
  final bool isLoadingNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.msgTrackCancelRequests,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${l10n.labelAvailabilityRequests}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: darkGray, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isLoadingNames)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _RestockRequestCard extends StatelessWidget {
  const _RestockRequestCard({
    required this.request,
    required this.productName,
    required this.isCancelling,
    required this.onCancel,
  });

  final RestockRequestModel request;
  final String productName;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusStyle = _statusStyle(context, request.status);
    final canCancel =
        request.status != RestockRequestStatus.converted &&
        request.status != RestockRequestStatus.cancelled &&
        !isCancelling;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusStyle.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusStyle.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusStyle.icon, color: statusStyle.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.labelProductId(request.productId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: darkGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 14),
          _DateRow(
            icon: Icons.schedule_outlined,
            text: l10n.labelRequestedDate(_formatDateTime(request.createdAt)),
          ),
          if (request.notifiedAt != null)
            _DateRow(
              icon: Icons.mark_email_read_outlined,
              text: l10n.labelNotifiedDate(
                _formatDateTime(request.notifiedAt!),
              ),
            ),
          if (request.convertedAt != null)
            _DateRow(
              icon: Icons.shopping_bag_outlined,
              text: l10n.labelConvertedDate(
                _formatDateTime(request.convertedAt!),
              ),
            ),
          if (request.cancelledAt != null)
            _DateRow(
              icon: Icons.cancel_outlined,
              text: l10n.labelCancelledDate(
                _formatDateTime(request.cancelledAt!),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canCancel
                  ? () => _confirmCancel(context, onCancel: onCancel)
                  : null,
              icon: isCancelling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close, size: 18),
              label: Text(
                request.status == RestockRequestStatus.converted
                    ? l10n.labelStatusPurchased
                    : request.status == RestockRequestStatus.cancelled
                    ? l10n.labelStatusCancelled
                    : l10n.btnCancelRequest,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: canCancel ? Colors.red.shade700 : darkGray,
                side: BorderSide(
                  color: canCancel
                      ? Colors.red.withValues(alpha: 0.28)
                      : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context, {
    required VoidCallback onCancel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.btnCancelRequest),
        content: Text(l10n.msgTrackCancelRequests),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(l10n.btnCancelRequest),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onCancel();
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: darkGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: darkGray, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RestockRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

({String label, Color color, IconData icon}) _statusStyle(
  BuildContext context,
  RestockRequestStatus status,
) {
  final l10n = AppLocalizations.of(context);
  return switch (status) {
    RestockRequestStatus.pending => (
      label: l10n.labelStatusPending,
      color: const Color(0xFF8C4F10),
      icon: Icons.hourglass_top_outlined,
    ),
    RestockRequestStatus.notified => (
      label: l10n.labelStatusNotified,
      color: const Color(0xFF155E99),
      icon: Icons.notifications_active_outlined,
    ),
    RestockRequestStatus.converted => (
      label: l10n.labelStatusPurchased,
      color: const Color(0xFF114F2D),
      icon: Icons.shopping_bag_outlined,
    ),
    RestockRequestStatus.cancelled => (
      label: l10n.labelStatusCancelled,
      color: const Color(0xFF4F4A45),
      icon: Icons.block_outlined,
    ),
  };
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return DateFormat.yMMMd().add_jm().format(value);
}
