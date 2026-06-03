import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';

class AppSnackBar {
  static void _show(
    BuildContext context,
    String message, {
    required Color accentColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).snackBarTheme.contentTextStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      accentColor: Colors.green.shade400,
      icon: Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      accentColor: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message,
      accentColor: gold,
      icon: Icons.warning_amber_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      accentColor: AppTheme.primary,
      icon: Icons.info_outline,
    );
  }
}
