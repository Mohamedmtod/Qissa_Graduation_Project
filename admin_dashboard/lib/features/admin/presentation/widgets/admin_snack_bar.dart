import 'package:flutter/material.dart';

import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';

enum AdminSnackBarTone { success, error, warning, info }

class AdminSnackBar {
  const AdminSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    AdminSnackBarTone tone = AdminSnackBarTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: EdgeInsets.zero,
        duration: tone == AdminSnackBarTone.error
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3),
        content: _AdminSnackBarContent(
          message: message,
          tone: tone,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, tone: AdminSnackBarTone.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, tone: AdminSnackBarTone.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, tone: AdminSnackBarTone.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message);
  }
}

class _AdminSnackBarContent extends StatelessWidget {
  const _AdminSnackBarContent({
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AdminSnackBarTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final spec = _AdminSnackBarSpec.forTone(tone);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.background, spec.backgroundDeep],
        ),
        border: Border.all(color: spec.border),
        boxShadow: [
          BoxShadow(
            color: spec.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -28,
              end: -18,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: spec.accent.withValues(alpha: 0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 14, 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: spec.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: spec.accent.withValues(alpha: 0.36),
                      ),
                    ),
                    child: Icon(spec.icon, color: spec.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: spec.accent,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSnackBarSpec {
  const _AdminSnackBarSpec({
    required this.icon,
    required this.accent,
    required this.background,
    required this.backgroundDeep,
    required this.border,
    required this.shadow,
  });

  final IconData icon;
  final Color accent;
  final Color background;
  final Color backgroundDeep;
  final Color border;
  final Color shadow;

  static _AdminSnackBarSpec forTone(AdminSnackBarTone tone) {
    return switch (tone) {
      AdminSnackBarTone.success => _AdminSnackBarSpec(
        icon: Icons.check_rounded,
        accent: AppTheme.tertiaryFixed,
        background: const Color(0xFF123B29),
        backgroundDeep: const Color(0xFF082719),
        border: const Color(0xFF3F7C5A),
        shadow: const Color(0x55123B29),
      ),
      AdminSnackBarTone.error => _AdminSnackBarSpec(
        icon: Icons.priority_high_rounded,
        accent: const Color(0xFFFFC9C2),
        background: const Color(0xFF5A1717),
        backgroundDeep: const Color(0xFF341010),
        border: const Color(0xFFB94F45),
        shadow: const Color(0x555A1717),
      ),
      AdminSnackBarTone.warning => _AdminSnackBarSpec(
        icon: Icons.warning_amber_rounded,
        accent: const Color(0xFFFFD49A),
        background: const Color(0xFF5C3511),
        backgroundDeep: const Color(0xFF36200A),
        border: const Color(0xFFC78337),
        shadow: const Color(0x555C3511),
      ),
      AdminSnackBarTone.info => _AdminSnackBarSpec(
        icon: Icons.info_outline_rounded,
        accent: AppTheme.primaryFixed,
        background: const Color(0xFF312429),
        backgroundDeep: const Color(0xFF1D171A),
        border: const Color(0xFF7C5962),
        shadow: const Color(0x55312429),
      ),
    };
  }
}
