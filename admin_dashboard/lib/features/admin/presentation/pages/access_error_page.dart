import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class AccessErrorPage extends StatelessWidget {
  const AccessErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: AdminSurfaceCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminPill(
                    label: l10n.t('accessError.badge'),
                    backgroundColor: const Color(0xFFFFF1D6),
                    foregroundColor: const Color(0xFF8A4D00),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('accessError.title'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.primary,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('accessError.message'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AdminPrimaryButton(
                        label: l10n.t('accessError.retry'),
                        icon: Icons.refresh,
                        onPressed: () {
                          context.read<AdminAuthCubit>().refreshAccess(
                            forceRefresh: true,
                          );
                        },
                      ),
                      AdminSecondaryButton(
                        label: l10n.t('unauthorized.signOut'),
                        icon: Icons.logout,
                        onPressed: () {
                          context.read<AdminAuthCubit>().signOut();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
