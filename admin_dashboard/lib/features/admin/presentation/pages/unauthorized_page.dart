import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

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
                    label: l10n.t('unauthorized.badge'),
                    backgroundColor: Color(0xFFFFE0E0),
                    foregroundColor: Color(0xFFB3261E),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('unauthorized.title'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.primary,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('unauthorized.message'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AdminPrimaryButton(
                        label: l10n.t('unauthorized.signOut'),
                        icon: Icons.logout,
                        onPressed: () {
                          context.read<AdminAuthCubit>().signOut();
                        },
                      ),
                      AdminSecondaryButton(
                        label: l10n.t('unauthorized.refresh'),
                        icon: Icons.refresh,
                        onPressed: () {
                          context.read<AdminAuthCubit>().refreshAccess();
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
