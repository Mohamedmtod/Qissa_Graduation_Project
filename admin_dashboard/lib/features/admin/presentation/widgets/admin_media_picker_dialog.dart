import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_media_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_media_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/media_file_picker/media_file_picker.dart';

class AdminMediaPickerSelection {
  const AdminMediaPickerSelection({required this.key, required this.url});

  final String key;
  final String url;
}

Future<AdminMediaPickerSelection?> showAdminMediaPickerDialog(
  BuildContext context, {
  AdminMediaFolder initialFolder = AdminMediaFolder.products,
}) {
  return showDialog<AdminMediaPickerSelection>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return BlocProvider(
        create: (_) =>
            AdminMediaCubit(dialogContext.read<AdminMediaRepository>())
              ..loadInitial(folder: initialFolder),
        child: const _AdminMediaPickerDialog(),
      );
    },
  );
}

class _AdminMediaPickerDialog extends StatefulWidget {
  const _AdminMediaPickerDialog();

  @override
  State<_AdminMediaPickerDialog> createState() =>
      _AdminMediaPickerDialogState();
}

class _AdminMediaPickerDialogState extends State<_AdminMediaPickerDialog> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: AdminSurfaceCard(
          padding: const EdgeInsets.all(22),
          color: Colors.white,
          child: BlocConsumer<AdminMediaCubit, AdminMediaState>(
            listenWhen: (previous, current) =>
                previous.feedbackMessage != current.feedbackMessage ||
                previous.errorMessage != current.errorMessage,
            listener: (context, state) {
              final message = state.feedbackMessage ?? state.errorMessage;
              if (message == null) {
                return;
              }
              AdminSnackBar.show(
                context,
                message: message,
                tone: state.errorMessage != null
                    ? AdminSnackBarTone.error
                    : AdminSnackBarTone.success,
              );
              context.read<AdminMediaCubit>().clearFeedback();
              context.read<AdminMediaCubit>().clearError();
            },
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    state: state,
                    onFolderSelected: (folder) {
                      context.read<AdminMediaCubit>().setFolder(folder);
                    },
                    onUploadPressed: () =>
                        _pickAndUpload(context, state.folder),
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: _buildBody(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminMediaState state) {
    final l10n = context.read<AdminLocaleController>();
    if (state.status == AdminMediaStatus.loading && state.items.isEmpty) {
      return AdminLoadingState(
        title: l10n.t('mediaPicker.title.loading', fallback: 'Loading Media'),
        message: l10n.t('mediaPicker.message.fetching', fallback: 'Fetching images from Cloudflare R2...'),
      );
    }
    if (state.status == AdminMediaStatus.error && state.items.isEmpty) {
      return AdminErrorState(
        title: l10n.t('mediaPicker.title.failed', fallback: 'Failed to Load Media'),
        message: state.errorMessage ?? 'Unknown error',
        onRetry: () => context.read<AdminMediaCubit>().loadInitial(),
      );
    }
    if (state.items.isEmpty) {
      return AdminEmptyState(
        title: l10n.t('mediaPicker.title.empty', fallback: 'No media found'),
        message: l10n.t('mediaPicker.message.empty', fallback: 'Upload a new image to start your media library.'),
        actionLabel: l10n.t('mediaPicker.button.uploadNew', fallback: 'Upload New'),
        onAction: () => _pickAndUpload(context, state.folder),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _MediaCard(
                item: item,
                deleting: state.activeDeleteKey == item.key,
                onSelect: () => _selectItem(context, item),
                onDelete: () => _confirmDelete(context, item),
              );
            },
          ),
        ),
        if (state.isLoadingMore) ...[
          const SizedBox(height: 10),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    AdminMediaFolder folder,
  ) async {
    final mediaCubit = context.read<AdminMediaCubit>();
    final picked = await pickMediaImageFile();
    if (!context.mounted || picked == null) {
      return;
    }

    final bytes = picked.bytes;
    final name = picked.name.trim();
    if (bytes.isEmpty || name.isEmpty) {
      final l10n = context.read<AdminLocaleController>();
      AdminSnackBar.error(
        context,
        l10n.t('mediaPicker.error.read', fallback: 'Could not read selected file. Please try another file.'),
      );
      return;
    }

    final contentType =
        (picked.contentType != null && picked.contentType!.trim().isNotEmpty)
        ? picked.contentType!.trim()
        : _resolveContentType(picked.extension, name);
    await mediaCubit.uploadNew(
      fileName: name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  Future<void> _confirmDelete(BuildContext context, AdminMediaItem item) async {
    final mediaCubit = context.read<AdminMediaCubit>();
    final l10n = context.read<AdminLocaleController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('mediaPicker.dialog.deleteTitle', fallback: 'Delete media')),
          content: Text(
            l10n.t(
              'mediaPicker.dialog.deleteConfirm',
              fallback: 'Are you sure you want to delete "{key}"?',
              params: {'key': item.key},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel', fallback: 'Cancel')),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('common.delete', fallback: 'Delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await mediaCubit.deleteByKey(item.key);
  }

  void _selectItem(BuildContext context, AdminMediaItem item) {
    Navigator.of(
      context,
    ).pop(AdminMediaPickerSelection(key: item.key, url: item.url));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    const threshold = 220.0;
    final position = _scrollController.position;
    final shouldLoadMore =
        position.maxScrollExtent - position.pixels <= threshold;
    if (shouldLoadMore) {
      context.read<AdminMediaCubit>().loadMore();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onFolderSelected,
    required this.onUploadPressed,
  });

  final AdminMediaState state;
  final ValueChanged<AdminMediaFolder> onFolderSelected;
  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<AdminLocaleController>();
    final uploadBusy = state.status == AdminMediaStatus.uploading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.t('mediaPicker.dialog.title', fallback: 'Media Manager'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppTheme.primary),
            ),
            const Spacer(),
            AdminPrimaryButton(
              label: uploadBusy ? l10n.t('common.saving', fallback: 'Saving...') : l10n.t('mediaPicker.button.uploadNew', fallback: 'Upload New'),
              icon: Icons.upload_file_rounded,
              onPressed: uploadBusy ? null : onUploadPressed,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AdminMediaFolder.values.map((folder) {
            final selected = folder == state.folder;
            return ChoiceChip(
              selected: selected,
              label: Text(folder.apiValue),
              onSelected: (_) => onFolderSelected(folder),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.onSelect,
    required this.onDelete,
    this.deleting = false,
  });

  final AdminMediaItem item;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceContainerHighest),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AdminNetworkImage(
                        imageUrl: item.url,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 12,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Delete',
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          color: Colors.white,
                          onPressed: deleting ? null : onDelete,
                          icon: deleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _displayFileName(item.key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _resolveContentType(String? extension, String fileName) {
  final ext = (extension ?? fileName.split('.').lastOrNull ?? '')
      .trim()
      .toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'avif':
      return 'image/avif';
    default:
      return 'application/octet-stream';
  }
}

String _displayFileName(String key) {
  final lastSegment = key.split('/').last.trim();
  if (lastSegment.isEmpty) {
    return key;
  }

  final uuidPrefixPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-(.+)$',
    caseSensitive: false,
  );
  final match = uuidPrefixPattern.firstMatch(lastSegment);
  if (match != null) {
    final extracted = match.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) {
      return extracted;
    }
  }

  return lastSegment;
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
