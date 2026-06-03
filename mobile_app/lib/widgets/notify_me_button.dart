import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/profile/data/repos/restock_notification_repo.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class NotifyMeButton extends StatefulWidget {
  const NotifyMeButton({
    super.key,
    required this.productId,
    this.height = 44,
    this.width,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 12,
    this.onSaved,
  });

  final String productId;
  final double height;
  final double? width;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final VoidCallback? onSaved;

  @override
  State<NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<NotifyMeButton> {
  final RestockNotificationRepo _repo = RestockNotificationRepo();
  bool _isLoading = false;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: ElevatedButton(
        onPressed: (_isLoading || _isSaved) ? null : _handlePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor ??
              Theme.of(context).colorScheme.surfaceContainerLowest,
          foregroundColor: widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface,
          disabledBackgroundColor: Colors.grey.shade100,
          disabledForegroundColor: darkGray,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: widget.compact ? 14 : 18,
                height: widget.compact ? 14 : 18,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSaved ? l10n.labelNotifySaved : l10n.btnNotifyMe,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: widget.compact ? 11 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _handlePressed() async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<AuthBloc>().state.user;
    log(
      'Notify Me tapped | productId=${widget.productId} userId=${user?.uid}',
      name: 'NotifyMeButton',
    );
    if (user == null) {
      log(
        'Notify Me requires login | productId=${widget.productId}',
        name: 'NotifyMeButton',
      );
      AppSnackBar.showWarning(context, l10n.msgNeedAccountToTrack);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _repo.requestNotification(
        userId: user.uid,
        productId: widget.productId,
      );
      if (!mounted) return;
      setState(() => _isSaved = true);
      log(
        'Notify Me saved in UI | productId=${widget.productId} userId=${user.uid}',
        name: 'NotifyMeButton',
      );
      widget.onSaved?.call();
      AppSnackBar.showWarning(context, l10n.msgNotifyMeRequestSaved);
    } catch (e, st) {
      log(
        'Notify Me failed in UI | productId=${widget.productId} userId=${user.uid}',
        name: 'NotifyMeButton',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      AppSnackBar.showError(context, l10n.msgCouldNotLoadRequests);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
