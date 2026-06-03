import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/shipping_zone_model.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_shipping_zones_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_shipping_zones_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_shipping_zones_state.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/shared_topbar.dart';

class DeliveryZonesPage extends StatelessWidget {
  const DeliveryZonesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminShippingZonesCubit(context.read<AdminShippingZonesService>()),
      child: const _DeliveryZonesView(),
    );
  }
}

class _DeliveryZonesView extends StatefulWidget {
  const _DeliveryZonesView();

  @override
  State<_DeliveryZonesView> createState() => _DeliveryZonesViewState();
}

class _DeliveryZonesViewState extends State<_DeliveryZonesView> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<AdminShippingZonesCubit>().loadZones();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocListener<AdminShippingZonesCubit, AdminShippingZonesState>(
      listener: (context, state) {
        if (state is AdminShippingZonesSuccess) {
          AdminSnackBar.success(context, state.message);
        } else if (state is AdminShippingZonesError) {
          AdminSnackBar.error(context, state.message);
        }
      },
      child: Column(
        children: [
          SharedTopbar(
            title: l10n.t(
              'deliveryZones.topbarTitle',
              fallback: 'Delivery Zones',
            ),
            searchHint: l10n.t(
              'deliveryZones.searchHint',
              fallback: 'Search by governorate, area, or code...',
            ),
            onSearchChanged: (value) => setState(() => _query = value),
            actions: [
              BlocBuilder<AdminShippingZonesCubit, AdminShippingZonesState>(
                builder: (context, state) {
                  final isSaving =
                      state is AdminShippingZonesLoaded && state.isSaving;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AdminSecondaryButton(
                        label: l10n.t(
                          'deliveryZones.addZone',
                          fallback: 'Add zone',
                        ),
                        icon: Icons.add,
                        onPressed: () => _showAddZoneDialog(context),
                      ),
                      AdminSecondaryButton(
                        label: l10n.t(
                          'deliveryZones.resetDefaults',
                          fallback: 'Reset defaults',
                        ),
                        icon: Icons.restore,
                        onPressed: isSaving
                            ? null
                            : () => context
                                  .read<AdminShippingZonesCubit>()
                                  .resetToDefaults(),
                      ),
                      AdminPrimaryButton(
                        label: isSaving
                            ? l10n.t('common.saving')
                            : l10n.t(
                                'deliveryZones.saveChanges',
                                fallback: 'Save changes',
                              ),
                        icon: Icons.save_outlined,
                        onPressed: isSaving
                            ? null
                            : () => context
                                  .read<AdminShippingZonesCubit>()
                                  .saveChanges(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Expanded(
            child:
                BlocBuilder<AdminShippingZonesCubit, AdminShippingZonesState>(
                  builder: (context, state) {
                    if (state is AdminShippingZonesLoading) {
                      return AdminLoadingState(
                        title: l10n.t(
                          'deliveryZones.loadingTitle',
                          fallback: 'Loading delivery zones',
                        ),
                      );
                    }

                    if (state is AdminShippingZonesError) {
                      return AdminErrorState(
                        title: l10n.t(
                          'deliveryZones.errorTitle',
                          fallback: 'Delivery zones unavailable',
                        ),
                        message: state.message,
                        onRetry: () =>
                            context.read<AdminShippingZonesCubit>().loadZones(),
                      );
                    }

                    if (state is AdminShippingZonesLoaded) {
                      final filtered = _filterZones(state.zones, _query);
                      if (filtered.isEmpty) {
                        return AdminEmptyState(
                          title: l10n.t(
                            'deliveryZones.noResultsTitle',
                            fallback: 'No matching zones',
                          ),
                          message: l10n.t(
                            'deliveryZones.noResultsMessage',
                            fallback:
                                'Try another governorate, area, or zone code.',
                          ),
                          icon: Icons.local_shipping_outlined,
                        );
                      }
                      return _ZonesList(zones: filtered);
                    }

                    return const SizedBox.shrink();
                  },
                ),
          ),
        ],
      ),
    );
  }

  List<ShippingZoneModel> _filterZones(
    List<ShippingZoneModel> zones,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return zones;

    final matches = zones.where((zone) {
      final searchable = [
        zone.code,
        zone.governorate,
        zone.governorateEn,
        ...zone.aliasesAr,
        ...zone.aliasesEn,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();

    final matchedCodes = matches.map((zone) => zone.code).toSet();
    final parentCodes = matches
        .map((zone) => zone.parentCode)
        .whereType<String>()
        .toSet();
    return zones.where((zone) {
      return matchedCodes.contains(zone.code) ||
          parentCodes.contains(zone.code);
    }).toList();
  }

  void _showAddZoneDialog(BuildContext context) {
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final codeController = TextEditingController();
    final feeController = TextEditingController(text: '50');
    final aliasesArController = TextEditingController();
    final aliasesEnController = TextEditingController();
    String? selectedParentCode;

    final l10n = context.read<AdminLocaleController>();
    final state = context.read<AdminShippingZonesCubit>().state;
    final parentZones = state is AdminShippingZonesLoaded
        ? state.zones.where((zone) => zone.parentCode == null).toList()
        : <ShippingZoneModel>[];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            l10n.t(
              'deliveryZones.addDialogTitle',
              fallback: 'Add delivery zone',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: selectedParentCode,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.parentLabel',
                      fallback: 'Parent governorate (optional)',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        l10n.t(
                          'deliveryZones.noParent',
                          fallback: 'None - main governorate',
                        ),
                      ),
                    ),
                    ...parentZones.map(
                      (zone) => DropdownMenuItem(
                        value: zone.code,
                        child: Text(zone.governorate),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedParentCode = value);
                  },
                ),
                TextField(
                  controller: nameArController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.nameArLabel',
                      fallback: 'Arabic area name',
                    ),
                  ),
                ),
                TextField(
                  controller: nameEnController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.nameEnLabel',
                      fallback: 'English area name',
                    ),
                  ),
                ),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.codeLabel',
                      fallback: 'Zone code, e.g. cairo_nasr_city',
                    ),
                  ),
                ),
                TextField(
                  controller: feeController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.feeLabel',
                      fallback: 'Shipping fee',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: aliasesArController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.aliasesArLabel',
                      fallback: 'Arabic aliases, comma separated',
                    ),
                  ),
                ),
                TextField(
                  controller: aliasesEnController,
                  decoration: InputDecoration(
                    labelText: l10n.t(
                      'deliveryZones.aliasesEnLabel',
                      fallback: 'English aliases, comma separated',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameArController.text.trim().isEmpty ||
                    nameEnController.text.trim().isEmpty ||
                    codeController.text.trim().isEmpty) {
                  return;
                }

                final newZone = ShippingZoneModel(
                  code: codeController.text.trim().toLowerCase(),
                  governorate: nameArController.text.trim(),
                  governorateEn: nameEnController.text.trim(),
                  fee: double.tryParse(feeController.text) ?? 50,
                  enabled: true,
                  parentCode: selectedParentCode,
                  aliasesAr: _splitAliases(aliasesArController.text),
                  aliasesEn: _splitAliases(aliasesEnController.text),
                );

                context.read<AdminShippingZonesCubit>().addZone(newZone);
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.t('common.add', fallback: 'Add')),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _splitAliases(String input) {
  return input
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

class _ZonesList extends StatelessWidget {
  const _ZonesList({required this.zones});

  final List<ShippingZoneModel> zones;

  @override
  Widget build(BuildContext context) {
    final parentZones = zones.where((zone) => zone.parentCode == null).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 860;
        if (isStacked) {
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: parentZones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final parent = parentZones[index];
              final children = zones
                  .where((zone) => zone.parentCode == parent.code)
                  .toList();
              return _ZoneCard(zone: parent, children: children);
            },
          );
        }

        final tableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(920.0, double.infinity)
            : 920.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: AdminSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const _ListHeader(),
                    const Divider(height: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: parentZones.length,
                      itemBuilder: (context, index) {
                        final parent = parentZones[index];
                        final children = zones
                            .where((zone) => zone.parentCode == parent.code)
                            .toList();

                        if (children.isEmpty) {
                          return Column(
                            children: [
                              _ZoneRow(zone: parent),
                              const Divider(height: 1),
                            ],
                          );
                        }

                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: _ZoneRow(zone: parent),
                            children: [
                              Container(
                                color: AppTheme.surfaceContainerLow.withValues(
                                  alpha: 0.5,
                                ),
                                child: Column(
                                  children: children
                                      .map(
                                        (child) => Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 32,
                                              ),
                                              child: _ZoneRow(zone: child),
                                            ),
                                            if (child != children.last)
                                              const Divider(
                                                height: 1,
                                                indent: 56,
                                              ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.children});

  final ShippingZoneModel zone;
  final List<ShippingZoneModel> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return AdminSurfaceCard(
        borderRadius: 8,
        padding: const EdgeInsets.all(16),
        child: _ZoneCardBody(zone: zone),
      );
    }

    return AdminSurfaceCard(
      borderRadius: 8,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: _ZoneCardHeader(zone: zone),
          children: children
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _ZoneCardBody(zone: child),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ZoneCardHeader extends StatelessWidget {
  const _ZoneCardHeader({required this.zone});

  final ShippingZoneModel zone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          zone.governorate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          zone.governorateEn,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _ZoneCardBody extends StatelessWidget {
  const _ZoneCardBody({required this.zone});

  final ShippingZoneModel zone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoneCardHeader(zone: zone),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminPill(
              label: zone.code,
              backgroundColor: AppTheme.surfaceContainerHighest,
              foregroundColor: AppTheme.primary,
            ),
            AdminPill(
              label: zone.enabled
                  ? l10n.t('deliveryZones.enabled', fallback: 'Enabled')
                  : l10n.t('deliveryZones.disabled', fallback: 'Disabled'),
              backgroundColor: zone.enabled
                  ? const Color(0xFFE4F4EA)
                  : const Color(0xFFFDE2E1),
              foregroundColor: zone.enabled
                  ? const Color(0xFF114F2D)
                  : const Color(0xFF9B1B1B),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: zone.fee.toStringAsFixed(0),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.t('deliveryZones.headerFee'),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            final newFee = double.tryParse(value) ?? zone.fee;
            context.read<AdminShippingZonesCubit>().updateZoneLocally(
              zone.copyWith(fee: newFee),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              l10n.t('deliveryZones.headerStatus', fallback: 'Status'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            Switch(
              value: zone.enabled,
              activeThumbColor: AppTheme.tertiary,
              onChanged: (value) {
                context.read<AdminShippingZonesCubit>().updateZoneLocally(
                  zone.copyWith(enabled: value),
                );
              },
            ),
            IconButton(
              tooltip: l10n.t(
                'deliveryZones.editAliases',
                fallback: 'Edit matching aliases',
              ),
              icon: const Icon(Icons.alt_route, color: AppTheme.primary),
              onPressed: () => _showAliasesDialog(context, zone),
            ),
            IconButton(
              tooltip: l10n.t('common.delete', fallback: 'Delete'),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                context.read<AdminShippingZonesCubit>().deleteZone(zone.code);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l10n.t(
                'deliveryZones.headerArea',
                fallback: 'Governorate / Area',
              ),
              style: _headerStyle(context),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.t('deliveryZones.headerCode', fallback: 'Zone code'),
              style: _headerStyle(context),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.t('deliveryZones.headerFee', fallback: 'Shipping fee'),
              style: _headerStyle(context),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                l10n.t('deliveryZones.headerStatus', fallback: 'Status'),
                style: _headerStyle(context),
              ),
            ),
          ),
          const SizedBox(width: 96),
        ],
      ),
    );
  }

  TextStyle? _headerStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge
      ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant);
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone});

  final ShippingZoneModel zone;

  @override
  Widget build(BuildContext context) {
    final isParent = zone.parentCode == null;
    final l10n = context.watch<AdminLocaleController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (!isParent)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.subdirectory_arrow_left,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.governorate,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: isParent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isParent ? AppTheme.primary : null,
                            ),
                      ),
                      Text(
                        zone.governorateEn,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: AdminPill(
              label: zone.code,
              backgroundColor: AppTheme.surfaceContainerHighest,
              foregroundColor: AppTheme.primary,
            ),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              width: 100,
              child: TextFormField(
                initialValue: zone.fee.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  final newFee = double.tryParse(value) ?? zone.fee;
                  context.read<AdminShippingZonesCubit>().updateZoneLocally(
                    zone.copyWith(fee: newFee),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Switch(
                value: zone.enabled,
                activeThumbColor: AppTheme.tertiary,
                onChanged: (value) {
                  context.read<AdminShippingZonesCubit>().updateZoneLocally(
                    zone.copyWith(enabled: value),
                  );
                },
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.t(
              'deliveryZones.editAliases',
              fallback: 'Edit matching aliases',
            ),
            icon: const Icon(
              Icons.alt_route,
              color: AppTheme.primary,
              size: 20,
            ),
            onPressed: () => _showAliasesDialog(context, zone),
          ),
          IconButton(
            tooltip: l10n.t('common.delete', fallback: 'Delete'),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () {
              context.read<AdminShippingZonesCubit>().deleteZone(zone.code);
            },
          ),
        ],
      ),
    );
  }
}

void _showAliasesDialog(BuildContext context, ShippingZoneModel zone) {
  final l10n = context.read<AdminLocaleController>();
  final aliasesArController = TextEditingController(
    text: zone.aliasesAr.join(', '),
  );
  final aliasesEnController = TextEditingController(
    text: zone.aliasesEn.join(', '),
  );

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        l10n.t(
          'deliveryZones.aliasesDialogTitle',
          fallback: 'Matching aliases - {zone}',
          params: {'zone': zone.governorate},
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: aliasesArController,
            decoration: InputDecoration(
              labelText: l10n.t(
                'deliveryZones.aliasesArLabel',
                fallback: 'Arabic aliases, comma separated',
              ),
            ),
          ),
          TextField(
            controller: aliasesEnController,
            decoration: InputDecoration(
              labelText: l10n.t(
                'deliveryZones.aliasesEnLabel',
                fallback: 'English aliases, comma separated',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.t('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<AdminShippingZonesCubit>().updateZoneLocally(
              zone.copyWith(
                aliasesAr: _splitAliases(aliasesArController.text),
                aliasesEn: _splitAliases(aliasesEnController.text),
              ),
            );
            Navigator.pop(dialogContext);
          },
          child: Text(l10n.t('common.save')),
        ),
      ],
    ),
  );
}
