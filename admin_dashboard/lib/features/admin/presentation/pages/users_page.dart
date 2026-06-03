import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_user_record.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_users_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final Set<String> _updatingUserIds = <String>{};

  Stream<List<AdminUserRecord>> _watchUsers(BuildContext context) {
    if (widget._firestore != null) {
      return widget._firestore!.collection('users').limit(200).snapshots().map((
        snapshot,
      ) {
        final users = snapshot.docs
            .map(AdminUserRecord.fromDoc)
            .toList(growable: false);
        return users.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
    return context.read<AdminUsersRepository>().watchUsers();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        SharedTopbar(
          title: l10n.t('users.topbarTitle', fallback: 'Users'),
          searchHint: l10n.t(
            'users.searchHint',
            fallback: 'Review customer accounts...',
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminUserRecord>>(
            stream: _watchUsers(context),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AdminErrorState(
                  title: l10n.t(
                    'users.errorTitle',
                    fallback: 'Users unavailable',
                  ),
                  message: snapshot.error.toString(),
                );
              }

              if (!snapshot.hasData) {
                return AdminLoadingState(
                  title: l10n.t(
                    'users.loadingTitle',
                    fallback: 'Loading users',
                  ),
                );
              }

              final users = snapshot.data ?? const <AdminUserRecord>[];

              if (users.isEmpty) {
                return AdminEmptyState(
                  title: l10n.t('users.emptyTitle', fallback: 'No users yet'),
                  message: l10n.t(
                    'users.emptyMessage',
                    fallback: 'Registered customer accounts will appear here.',
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AdminSurfaceCard(
                  padding: const EdgeInsets.all(0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: [
                        DataColumn(
                          label: Text(
                            l10n.t('users.column.name', fallback: 'Name'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t('users.column.email', fallback: 'Email'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t('users.column.role', fallback: 'Role'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t('users.column.created', fallback: 'Created'),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.t('users.column.actions', fallback: 'Actions'),
                          ),
                        ),
                      ],
                      rows: users
                          .map(
                            (user) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    user.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    user.email,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(_RolePill(role: user.role)),
                                DataCell(
                                  Text(
                                    user.createdLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(
                                  _RoleActionButton(
                                    user: user,
                                    isCurrentAdmin: user.id == currentAdminUid,
                                    isUpdating: _updatingUserIds.contains(
                                      user.id,
                                    ),
                                    onRoleSelected: (role) =>
                                        _updateRole(user, role),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateRole(AdminUserRecord user, String role) async {
    if (widget._firestore != null || user.role == role) {
      return;
    }
    setState(() => _updatingUserIds.add(user.id));
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.read<AdminLocaleController>();

    try {
      final result = await context.read<AdminUsersRepository>().updateUserRole(
        user: user,
        role: role,
      );
      _showSnackBar(
        messenger,
        l10n.t(
          'users.role.updated',
          fallback:
              'Role updated to ${result.data.role}. Trace: ${result.traceId}',
          params: {'role': result.data.role, 'traceId': result.traceId},
        ),
      );
    } on AdminSecurityException catch (error) {
      _showSnackBar(messenger, error.message);
    } catch (error) {
      _showSnackBar(messenger, error.toString());
    } finally {
      if (mounted) {
        setState(() => _updatingUserIds.remove(user.id));
      }
    }
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _RoleActionButton extends StatelessWidget {
  const _RoleActionButton({
    required this.user,
    required this.isCurrentAdmin,
    required this.isUpdating,
    required this.onRoleSelected,
  });

  final AdminUserRecord user;
  final bool isCurrentAdmin;
  final bool isUpdating;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    if (isUpdating) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (isCurrentAdmin && user.role == 'admin') {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Tooltip(
            message: l10n.t(
              'users.role.selfDemoteBlocked',
              fallback: 'You cannot remove your own admin access.',
            ),
            child: IconButton(
              onPressed: null,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(
                width: 40,
                height: 40,
              ),
              icon: const Icon(Icons.lock_outline),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: PopupMenuButton<String>(
          tooltip: l10n.t('users.role.change', fallback: 'Change role'),
          padding: EdgeInsets.zero,
          onSelected: onRoleSelected,
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'user',
              enabled: user.role != 'user',
              child: Text(l10n.t('users.role.user', fallback: 'User')),
            ),
            PopupMenuItem<String>(
              value: 'admin',
              enabled: user.role != 'admin',
              child: Text(l10n.t('users.role.admin', fallback: 'Admin')),
            ),
          ],
          child: const Icon(Icons.more_horiz),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return AdminPill(
      label: role.isEmpty ? 'user' : role.toUpperCase(),
      backgroundColor: isAdmin
          ? AppTheme.primary.withValues(alpha: 0.12)
          : AppTheme.surfaceContainerHigh,
      foregroundColor: isAdmin ? AppTheme.primary : AppTheme.onSurfaceVariant,
      icon: isAdmin
          ? Icons.admin_panel_settings_outlined
          : Icons.person_outline,
    );
  }
}
