import 'package:flutter/material.dart';

import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class TopbarTab {
  const TopbarTab({required this.label, this.active = false, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;
}

class SharedTopbar extends StatelessWidget {
  const SharedTopbar({
    super.key,
    required this.title,
    required this.searchHint,
    this.tabs = const [],
    this.onSearchChanged,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.actions = const [],
  });

  final String title;
  final String searchHint;
  final List<TopbarTab> tabs;
  final List<Widget> actions;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 980;

          return Column(
            children: [
              if (isStacked) ...[
                _TopbarLeft(title: title, tabs: tabs),
                const SizedBox(height: 18),
                _TopbarRight(
                  searchHint: searchHint,
                  onSearchChanged: onSearchChanged,
                  onNotificationsTap: onNotificationsTap,
                  onSettingsTap: onSettingsTap,
                  actions: actions,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _TopbarLeft(title: title, tabs: tabs),
                    ),
                    const SizedBox(width: 24),
                    _TopbarRight(
                      searchHint: searchHint,
                      onSearchChanged: onSearchChanged,
                      onNotificationsTap: onNotificationsTap,
                      onSettingsTap: onSettingsTap,
                      actions: actions,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopbarLeft extends StatelessWidget {
  const _TopbarLeft({required this.title, required this.tabs});

  final String title;
  final List<TopbarTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 28,
      runSpacing: 12,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
        ),
        if (tabs.isNotEmpty)
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: tabs.map((tab) {
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: tab.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: tab.active
                        ? Border(
                            bottom: BorderSide(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  child: Text(
                    tab.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tab.active
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _TopbarRight extends StatelessWidget {
  const _TopbarRight({
    required this.searchHint,
    required this.onSearchChanged,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.actions,
  });

  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        if (onSearchChanged != null)
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        _TopbarIconButton(
          icon: Icons.notifications_outlined,
          onTap: onNotificationsTap,
        ),
        _TopbarIconButton(icon: Icons.settings_outlined, onTap: onSettingsTap),
        if (actions.isNotEmpty) ...[const SizedBox(width: 8), ...actions],
        const AdminNetworkImage(
          imageUrl:
              'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
          width: 40,
          height: 40,
          borderRadius: 999,
        ),
      ],
    );
  }
}

class _TopbarIconButton extends StatelessWidget {
  const _TopbarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppTheme.surfaceContainerLow.withValues(alpha: 0.42)
          : AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: onTap == null
                ? AppTheme.onSurfaceVariant.withValues(alpha: 0.52)
                : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
