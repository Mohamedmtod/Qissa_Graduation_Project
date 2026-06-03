import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_item.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_media_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';

enum AdminMediaStatus { initial, loading, loaded, uploading, deleting, error }

class AdminMediaState extends Equatable {
  const AdminMediaState({
    this.status = AdminMediaStatus.initial,
    this.folder = AdminMediaFolder.products,
    this.items = const <AdminMediaItem>[],
    this.cursor,
    this.truncated = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.feedbackMessage,
    this.activeDeleteKey,
  });

  final AdminMediaStatus status;
  final AdminMediaFolder folder;
  final List<AdminMediaItem> items;
  final String? cursor;
  final bool truncated;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? feedbackMessage;
  final String? activeDeleteKey;

  bool get canLoadMore => truncated && cursor != null && cursor!.isNotEmpty;

  AdminMediaState copyWith({
    AdminMediaStatus? status,
    AdminMediaFolder? folder,
    List<AdminMediaItem>? items,
    String? cursor,
    bool clearCursor = false,
    bool? truncated,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
    String? activeDeleteKey,
    bool clearActiveDeleteKey = false,
  }) {
    return AdminMediaState(
      status: status ?? this.status,
      folder: folder ?? this.folder,
      items: items ?? this.items,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      truncated: truncated ?? this.truncated,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      feedbackMessage: clearFeedback
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      activeDeleteKey: clearActiveDeleteKey
          ? null
          : activeDeleteKey ?? this.activeDeleteKey,
    );
  }

  @override
  List<Object?> get props => [
    status,
    folder,
    items,
    cursor,
    truncated,
    isLoadingMore,
    errorMessage,
    feedbackMessage,
    activeDeleteKey,
  ];
}

class AdminMediaCubit extends Cubit<AdminMediaState> {
  AdminMediaCubit(this._repository) : super(const AdminMediaState());

  final AdminMediaRepository _repository;

  Future<void> loadInitial({AdminMediaFolder? folder}) async {
    final targetFolder = folder ?? state.folder;
    emit(
      state.copyWith(
        status: AdminMediaStatus.loading,
        folder: targetFolder,
        items: const <AdminMediaItem>[],
        truncated: false,
        isLoadingMore: false,
        clearCursor: true,
        clearError: true,
        clearFeedback: true,
        clearActiveDeleteKey: true,
      ),
    );

    try {
      final page = await _repository.listMedia(folder: targetFolder);
      emit(
        state.copyWith(
          status: AdminMediaStatus.loaded,
          items: page.items,
          cursor: page.cursor,
          truncated: page.truncated,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } on AdminSecurityException catch (error) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: error.message,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: 'Failed to load media assets.',
          isLoadingMore: false,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.status == AdminMediaStatus.loading ||
        state.status == AdminMediaStatus.uploading ||
        state.status == AdminMediaStatus.deleting ||
        state.isLoadingMore ||
        !state.canLoadMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final page = await _repository.listMedia(
        folder: state.folder,
        cursor: state.cursor,
      );
      emit(
        state.copyWith(
          status: AdminMediaStatus.loaded,
          items: <AdminMediaItem>[...state.items, ...page.items],
          cursor: page.cursor,
          truncated: page.truncated,
          isLoadingMore: false,
        ),
      );
    } on AdminSecurityException catch (error) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: error.message,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: 'Failed to load more media assets.',
          isLoadingMore: false,
        ),
      );
    }
  }

  Future<void> uploadNew({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    emit(
      state.copyWith(
        status: AdminMediaStatus.uploading,
        clearError: true,
        clearFeedback: true,
      ),
    );
    try {
      final result = await _repository.uploadMedia(
        folder: state.folder,
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
      );
      emit(
        state.copyWith(
          feedbackMessage: 'Uploaded successfully. Trace: ${result.traceId}',
        ),
      );
      await loadInitial(folder: state.folder);
    } on AdminSecurityException catch (error) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: 'Failed to upload media.',
        ),
      );
    }
  }

  Future<void> deleteByKey(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        status: AdminMediaStatus.deleting,
        activeDeleteKey: normalizedKey,
        clearError: true,
        clearFeedback: true,
      ),
    );
    try {
      final result = await _repository.deleteMedia(key: normalizedKey);
      final updatedItems = state.items
          .where((item) => item.key != normalizedKey)
          .toList();
      emit(
        state.copyWith(
          status: AdminMediaStatus.loaded,
          items: updatedItems,
          feedbackMessage: 'Deleted successfully. Trace: ${result.traceId}',
          clearActiveDeleteKey: true,
        ),
      );
    } on AdminSecurityException catch (error) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: error.message,
          clearActiveDeleteKey: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: AdminMediaStatus.error,
          errorMessage: 'Failed to delete media.',
          clearActiveDeleteKey: true,
        ),
      );
    }
  }

  Future<void> setFolder(AdminMediaFolder folder) async {
    if (folder == state.folder) {
      return;
    }
    await loadInitial(folder: folder);
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
