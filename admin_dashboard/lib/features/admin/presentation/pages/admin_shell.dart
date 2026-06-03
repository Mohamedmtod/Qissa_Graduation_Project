import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/router/app_router.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    // Refresh once on shell mount to surface latest profile fields in sidebar.
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<AdminAuthCubit>().refreshAccess(forceRefresh: true);
    });
  }

  List<_SidebarDestination> _destinations(AdminLocaleController l10n) {
    return [
      _SidebarDestination(
        label: l10n.t('nav.dashboard'),
        icon: Icons.dashboard_outlined,
        route: AppRouter.dashboard,
      ),
      _SidebarDestination(
        label: l10n.t('nav.orders'),
        icon: Icons.shopping_bag_outlined,
        route: AppRouter.orders,
      ),
      _SidebarDestination(
        label: l10n.t('nav.inventory'),
        icon: Icons.inventory_2_outlined,
        route: AppRouter.inventory,
      ),
      _SidebarDestination(
        label: l10n.t('nav.content'),
        icon: Icons.auto_stories_outlined,
        route: AppRouter.content,
      ),
      _SidebarDestination(
        label: l10n.t('nav.users', fallback: 'Users'),
        icon: Icons.manage_accounts_outlined,
        route: AppRouter.users,
      ),
      _SidebarDestination(
        label: l10n.t('nav.finance'),
        icon: Icons.payments_outlined,
        route: AppRouter.finance,
      ),
      _SidebarDestination(
        label: l10n.t('nav.aiInsights'),
        icon: Icons.auto_awesome_outlined,
        route: AppRouter.aiInsights,
      ),
      _SidebarDestination(
        label: l10n.t('nav.deliveryZones'),
        icon: Icons.local_shipping_outlined,
        route: AppRouter.deliveryZones,
      ),
      _SidebarDestination(
        label: l10n.t('nav.pos', fallback: 'POS'),
        icon: Icons.point_of_sale_outlined,
        route: AppRouter.pos,
      ),
      _SidebarDestination(
        label: l10n.t('nav.recipes', fallback: 'Recipes'),
        icon: Icons.receipt_long_outlined,
        route: AppRouter.recipes,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<AdminLocaleController>();
    final authState = context.watch<AdminAuthCubit>().state;
    final isArabic = localeController.isArabic;
    final currentPath = GoRouterState.of(context).uri.path;
    final profileName = authState.profileName?.trim().isNotEmpty == true
        ? authState.profileName!.trim()
        : localeController.t('sidebar.profileName');
    final profileRole = _resolveProfileRole(
      role: authState.role,
      localeController: localeController,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final destinations = _destinations(localeController);
        final mobile = constraints.maxWidth < 720;
        final compact = constraints.maxWidth < 1320;
        final railWidth = compact ? 108.0 : 288.0;

        if (mobile) {
          final currentIndex = _activeDestinationIndex(
            destinations: destinations,
            currentPath: currentPath,
          );
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.92),
                ),
                child: widget.child,
              ),
            ),
            bottomNavigationBar: _MobileDestinationBar(
              destinations: destinations,
              currentIndex: currentIndex,
              currentPath: currentPath,
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.surface,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFCFAF6),
                  Color(0xFFF5F0EB),
                  Color(0xFFF9F7F2),
                ],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: railWidth,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 22,
                      24,
                      compact ? 14 : 22,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow.withValues(
                        alpha: 0.72,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.onSurface.withValues(alpha: 0.05),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: railWidth - (compact ? 28 : 44),
                        child: _ShellSidebar(
                          currentPath: currentPath,
                          destinations: destinations,
                          compact: compact,
                          isArabic: isArabic,
                          brandTitle: localeController.t('sidebar.brandTitle'),
                          brandSubtitle: localeController.t(
                            'sidebar.brandSubtitle',
                          ),
                          profileName: profileName,
                          profileRole: profileRole,
                          settingsLabel: localeController.t('sidebar.settings'),
                          supportLabel: localeController.t('sidebar.support'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.78),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _resolveProfileRole({
  required String? role,
  required AdminLocaleController localeController,
}) {
  final normalizedRole = role?.trim().toLowerCase();
  if (normalizedRole == null || normalizedRole.isEmpty) {
    return localeController.t('sidebar.profileRole');
  }

  if (normalizedRole == 'admin') {
    return localeController.t('roles.admin', fallback: 'Admin');
  }

  return normalizedRole;
}

int _activeDestinationIndex({
  required List<_SidebarDestination> destinations,
  required String currentPath,
}) {
  final index = destinations.indexWhere(
    (destination) => destination.route == currentPath,
  );
  return index < 0 ? 0 : index;
}

class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.currentPath,
    required this.destinations,
    required this.compact,
    required this.isArabic,
    required this.brandTitle,
    required this.brandSubtitle,
    required this.profileName,
    required this.profileRole,
    required this.settingsLabel,
    required this.supportLabel,
  });

  final String currentPath;
  final List<_SidebarDestination> destinations;
  final bool compact;
  final bool isArabic;
  final String brandTitle;
  final String brandSubtitle;
  final String profileName;
  final String profileRole;
  final String settingsLabel;
  final String supportLabel;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
                child: compact
                    ? const AdminNetworkImage(
                        imageUrl:
                            'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                        width: 52,
                        height: 52,
                        borderRadius: 999,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brandTitle,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontSize: 24,
                                  fontStyle: isArabic
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                  color: AppTheme.primary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            brandSubtitle,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              letterSpacing: isArabic ? 0 : 2.2,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < destinations.length; i++) ...[
                    _SidebarItem(
                      destination: destinations[i],
                      currentPath: currentPath,
                      compact: compact,
                    ),
                    if (i < destinations.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SidebarAction(
                    icon: Icons.settings_outlined,
                    label: settingsLabel,
                    compact: compact,
                    onTap: () => _showSettingsSheet(context),
                  ),
                  const SizedBox(height: 6),
                  _SidebarAction(
                    icon: Icons.help_outline,
                    label: supportLabel,
                    compact: compact,
                    onTap: () => _showSupportSheet(context),
                  ),
                  const SizedBox(height: 18),
                  compact
                      ? const AdminNetworkImage(
                          imageUrl:
                              'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                          width: 52,
                          height: 52,
                          borderRadius: 999,
                        )
                      : AdminSurfaceCard(
                          padding: const EdgeInsets.all(16),
                          color: AppTheme.primaryContainer.withValues(alpha: 0.12),
                          borderRadius: 20,
                          shadow: const [],
                          child: Row(
                            children: [
                              const AdminNetworkImage(
                                imageUrl:
                                    'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                                width: 44,
                                height: 44,
                                borderRadius: 999,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profileName,
                                      style: Theme.of(context).textTheme.labelLarge
                                          ?.copyWith(color: AppTheme.primary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profileRole,
                                      style: Theme.of(context).textTheme.labelSmall
                                          ?.copyWith(
                                            color: AppTheme.primary.withValues(
                                              alpha: 0.7,
                                            ),
                                            letterSpacing: isArabic ? 0 : 1.2,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.currentPath,
    required this.compact,
  });

  final _SidebarDestination destination;
  final String currentPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isActive = currentPath == destination.route;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surfaceContainerLowest.withValues(alpha: 0.74)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: isActive
            ? Border(
                left: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.56),
                  width: 4,
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(
            destination.icon,
            color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
          ),
          if (!compact) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isActive
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: destination.label,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go(destination.route),
          child: content,
        ),
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.compact,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppTheme.onSurfaceVariant),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return compact ? Tooltip(message: label, child: child) : child;
  }
}

class _SidebarDestination {
  const _SidebarDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _MobileDestinationBar extends StatelessWidget {
  const _MobileDestinationBar({
    required this.destinations,
    required this.currentIndex,
    required this.currentPath,
  });

  final List<_SidebarDestination> destinations;
  final int currentIndex;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: AppTheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _MobileDestinationButton(
                    destination: destinations[index],
                    active: index == currentIndex,
                    onTap: () {
                      final route = destinations[index].route;
                      if (route != currentPath) {
                        context.go(route);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileDestinationButton extends StatelessWidget {
  const _MobileDestinationButton({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final _SidebarDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: Material(
        color: active
            ? AppTheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76, maxWidth: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    destination.icon,
                    size: 21,
                    color: active
                        ? AppTheme.primary
                        : AppTheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: active
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
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

void _showSupportSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTheme.surface,
    builder: (sheetContext) {
      return Consumer<AdminLocaleController>(
        builder: (context, localeController, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localeController.t('support.title'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localeController.t('support.message'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  AdminSecondaryButton(
                    label: localeController.t('common.dismiss'),
                    icon: Icons.close,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTheme.surface,
    builder: (sheetContext) {
      return Consumer<AdminLocaleController>(
        builder: (context, localeController, _) {
          final selectedLanguageCode = localeController.locale.languageCode;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localeController.t('settings.languageTitle'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localeController.t('settings.languageSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _LanguageOptionTile(
                    title: localeController.t('settings.languageArabic'),
                    subtitle: localeController.t(
                      'settings.languageArabicSubtitle',
                    ),
                    selected: selectedLanguageCode == 'ar',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      localeController.updateLocale(
                        const Locale('ar', 'EG'),
                        forceReload: true,
                      );
                    },
                  ),
                  _LanguageOptionTile(
                    title: localeController.t('settings.languageEnglish'),
                    subtitle: localeController.t(
                      'settings.languageEnglishSubtitle',
                    ),
                    selected: selectedLanguageCode == 'en',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      localeController.updateLocale(
                        const Locale('en', 'US'),
                        forceReload: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppTheme.primary : AppTheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
