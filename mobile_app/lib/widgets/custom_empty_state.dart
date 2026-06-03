import 'package:flutter/material.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

/// A reusable empty / info-state widget.
///
/// Use this across any page that needs to show an empty list, a "no results"
/// message, or a recoverable error state.
class CustomEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final IconData? actionIcon;

  const CustomEmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.subtitle,
    this.onRetry,
    this.actionLabel,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: darkGray),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(actionIcon ?? Icons.refresh, size: 18),
                label: Text(actionLabel ?? l10n.btnTryAgain),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
