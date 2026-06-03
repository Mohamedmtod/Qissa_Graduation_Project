import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_dashboard_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_finance_snapshot.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/models/business_config_model.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_analytics_repository.dart';

class AdminAnalyticsState extends Equatable {
  const AdminAnalyticsState({
    this.isLoading = false,
    this.isSavingSettings = false,
    this.dashboardSnapshot,
    this.financeSnapshot,
    this.dashboardErrorMessage,
    this.financeErrorMessage,
    this.serverCosts = 0,
    this.operatingCosts = 0,
    this.additionalFixedCosts = 0,
    this.averageOrderValue = 0,
    this.grossMargin = 0,
  });

  final bool isLoading;
  final bool isSavingSettings;
  final AdminDashboardSnapshot? dashboardSnapshot;
  final AdminFinanceSnapshot? financeSnapshot;
  final String? dashboardErrorMessage;
  final String? financeErrorMessage;
  final double serverCosts;
  final double operatingCosts;
  final double additionalFixedCosts;
  final double averageOrderValue;
  final double grossMargin;

  double get fixedCosts => serverCosts + operatingCosts + additionalFixedCosts;

  double get contributionPerOrder => averageOrderValue * grossMargin;

  int get breakEvenOrders {
    final contribution = contributionPerOrder;
    if (contribution <= 0) {
      return 0;
    }

    return (fixedCosts / contribution).ceil();
  }

  double get breakEvenRevenue => breakEvenOrders * averageOrderValue;

  AdminAnalyticsState copyWith({
    bool? isLoading,
    bool? isSavingSettings,
    AdminDashboardSnapshot? dashboardSnapshot,
    bool clearDashboardSnapshot = false,
    AdminFinanceSnapshot? financeSnapshot,
    bool clearFinanceSnapshot = false,
    String? dashboardErrorMessage,
    bool clearDashboardError = false,
    String? financeErrorMessage,
    bool clearFinanceError = false,
    double? serverCosts,
    double? operatingCosts,
    double? additionalFixedCosts,
    double? averageOrderValue,
    double? grossMargin,
  }) {
    return AdminAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      isSavingSettings: isSavingSettings ?? this.isSavingSettings,
      dashboardSnapshot: clearDashboardSnapshot
          ? null
          : dashboardSnapshot ?? this.dashboardSnapshot,
      financeSnapshot: clearFinanceSnapshot
          ? null
          : financeSnapshot ?? this.financeSnapshot,
      dashboardErrorMessage: clearDashboardError
          ? null
          : dashboardErrorMessage ?? this.dashboardErrorMessage,
      financeErrorMessage: clearFinanceError
          ? null
          : financeErrorMessage ?? this.financeErrorMessage,
      serverCosts: serverCosts ?? this.serverCosts,
      operatingCosts: operatingCosts ?? this.operatingCosts,
      additionalFixedCosts: additionalFixedCosts ?? this.additionalFixedCosts,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      grossMargin: grossMargin ?? this.grossMargin,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSavingSettings,
    dashboardSnapshot,
    financeSnapshot,
    dashboardErrorMessage,
    financeErrorMessage,
    serverCosts,
    operatingCosts,
    additionalFixedCosts,
    averageOrderValue,
    grossMargin,
  ];
}

class AdminAnalyticsCubit extends Cubit<AdminAnalyticsState> {
  AdminAnalyticsCubit(this._repository) : super(const AdminAnalyticsState());

  final AdminAnalyticsRepository _repository;

  Future<void> loadDashboard() async {
    emit(state.copyWith(isLoading: true, clearDashboardError: true));
    try {
      final snapshot = await _repository.fetchDashboardSnapshot();
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, dashboardSnapshot: snapshot));
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][analytics][load_dashboard_failed] '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrint('[admin][analytics][load_dashboard_failed_stack] $stackTrace');
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          clearDashboardSnapshot: true,
          dashboardErrorMessage: AdminLocaleController.globalT(
            'errors.analytics.dashboardLoadFailed',
          ),
        ),
      );
    }
  }

  Future<void> loadFinance() async {
    emit(state.copyWith(isLoading: true, clearFinanceError: true));
    try {
      final results = await Future.wait([
        _repository.fetchFinanceSnapshot(),
        _repository.fetchBusinessConfig(),
      ]);
      final snapshot = results[0] as AdminFinanceSnapshot;
      final config = results[1] as BusinessConfigModel;

      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          financeSnapshot: snapshot,
          serverCosts: config.serverCosts,
          operatingCosts: config.manufacturingCosts,
          additionalFixedCosts: config.otherFixedCosts,
          averageOrderValue: snapshot.initialAverageOrderValue,
          grossMargin: snapshot.initialGrossMargin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[admin][analytics][load_finance_failed] '
        'errorType=${error.runtimeType} error=$error',
      );
      debugPrint('[admin][analytics][load_finance_failed_stack] $stackTrace');
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          clearFinanceSnapshot: true,
          financeErrorMessage: AdminLocaleController.globalT(
            'errors.analytics.financeLoadFailed',
          ),
        ),
      );
    }
  }

  void updateServerCosts(double value) {
    emit(state.copyWith(serverCosts: value));
  }

  void updateOperatingCosts(double value) {
    emit(state.copyWith(operatingCosts: value));
  }

  void updateAdditionalFixedCosts(double value) {
    emit(state.copyWith(additionalFixedCosts: value));
  }

  Future<bool> saveSettings() async {
    emit(state.copyWith(isSavingSettings: true));
    try {
      await _repository.saveBusinessConfig(
        BusinessConfigModel(
          serverCosts: state.serverCosts,
          manufacturingCosts: state.operatingCosts,
          otherFixedCosts: state.additionalFixedCosts,
          updatedAt: DateTime.now(),
        ),
      );
      if (isClosed) return true;
      emit(state.copyWith(isSavingSettings: false));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isSavingSettings: false));
      return false;
    }
  }

  void updateAverageOrderValue(double value) {
    emit(state.copyWith(averageOrderValue: value));
  }

  void updateGrossMargin(double value) {
    emit(state.copyWith(grossMargin: value));
  }
}
