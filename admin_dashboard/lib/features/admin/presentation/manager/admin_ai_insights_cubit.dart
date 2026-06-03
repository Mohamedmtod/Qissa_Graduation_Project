import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_ai_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_ai_insights_repository.dart';

class AdminAiInsightsState extends Equatable {
  const AdminAiInsightsState({
    this.isLoading = false,
    this.isTraining = false,
    this.snapshot,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isTraining;
  final AdminAiInsightsSnapshot? snapshot;
  final String? errorMessage;

  AdminAiInsightsState copyWith({
    bool? isLoading,
    bool? isTraining,
    AdminAiInsightsSnapshot? snapshot,
    bool clearSnapshot = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminAiInsightsState(
      isLoading: isLoading ?? this.isLoading,
      isTraining: isTraining ?? this.isTraining,
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, isTraining, snapshot, errorMessage];
}

class AdminAiInsightsCubit extends Cubit<AdminAiInsightsState> {
  AdminAiInsightsCubit(this._repository) : super(const AdminAiInsightsState());

  final AdminAiInsightsRepository _repository;

  Future<void> loadInsights() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final snapshot = await _repository.fetchInsightsSnapshot();
      emit(state.copyWith(isLoading: false, snapshot: snapshot));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          clearSnapshot: true,
          errorMessage: AdminLocaleController.globalT('errors.ai.loadFailed'),
        ),
      );
    }
  }

  Future<bool> trainModel() async {
    emit(state.copyWith(isTraining: true));
    try {
      await _repository.queueModelTraining();
      emit(state.copyWith(isTraining: false));
      await loadInsights();
      return true;
    } catch (_) {
      emit(state.copyWith(isTraining: false));
      return false;
    }
  }
}
