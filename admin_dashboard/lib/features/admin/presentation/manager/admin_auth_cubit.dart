import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_auth_repository.dart';

enum AdminAuthViewStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  unauthorized,
  failure,
}

class AdminAuthState extends Equatable {
  const AdminAuthState({
    required this.status,
    this.email = '',
    this.profileName,
    this.role,
    this.errorMessage,
  });

  const AdminAuthState.initial()
    : status = AdminAuthViewStatus.initial,
      email = '',
      profileName = null,
      role = null,
      errorMessage = null;

  final AdminAuthViewStatus status;
  final String email;
  final String? profileName;
  final String? role;
  final String? errorMessage;

  AdminAuthState copyWith({
    AdminAuthViewStatus? status,
    String? email,
    String? profileName,
    String? role,
    String? errorMessage,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      profileName: clearProfile ? null : profileName ?? this.profileName,
      role: clearProfile ? null : role ?? this.role,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, email, profileName, role, errorMessage];
}

class AdminAuthCubit extends Cubit<AdminAuthState> {
  AdminAuthCubit(this._authRepository) : super(const AdminAuthState.initial()) {
    _authSubscription = _authRepository.authStateChanges.listen((_) {
      refreshAccess();
    });
  }

  final AdminAuthRepository _authRepository;
  late final StreamSubscription<dynamic> _authSubscription;

  Future<void> refreshAccess({bool forceRefresh = false}) async {
    final access = await _authRepository.resolveAccess(
      forceRefresh: forceRefresh,
    );

    switch (access.status) {
      case AdminAccessStatus.authorized:
        emit(
          state.copyWith(
            status: AdminAuthViewStatus.authenticated,
            email: access.user?.email ?? '',
            profileName: access.profileName,
            role: access.role,
            clearError: true,
          ),
        );
      case AdminAccessStatus.unauthenticated:
        emit(
          state.copyWith(
            status: AdminAuthViewStatus.unauthenticated,
            email: '',
            clearProfile: true,
            clearError: true,
          ),
        );
      case AdminAccessStatus.unauthorized:
        emit(
          state.copyWith(
            status: AdminAuthViewStatus.unauthorized,
            email: access.user?.email ?? '',
            profileName: access.profileName,
            role: access.role,
            errorMessage: AdminLocaleController.globalT(
              'errors.auth.missingAdminRole',
            ),
          ),
        );
      case AdminAccessStatus.recoverableFailure:
        emit(
          state.copyWith(
            status: AdminAuthViewStatus.failure,
            email: access.user?.email ?? '',
            profileName: access.profileName,
            role: access.role,
            errorMessage: AdminLocaleController.globalT(
              'errors.auth.accessCheckRecoverable',
              params: {'code': access.errorCode ?? 'network'},
            ),
          ),
        );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AdminAuthViewStatus.loading, clearError: true));

    try {
      await _authRepository.signIn(email: email, password: password);
      await refreshAccess();
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminAuthViewStatus.failure,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(status: AdminAuthViewStatus.loading, clearError: true));
    await _authRepository.signOut();
    emit(
      state.copyWith(
        status: AdminAuthViewStatus.unauthenticated,
        email: '',
        clearProfile: true,
        clearError: true,
      ),
    );
  }

  String _mapError(Object error) {
    final text = error.toString();
    if (text.contains('wrong-password') ||
        text.contains('invalid-credential')) {
      return AdminLocaleController.globalT('errors.auth.invalidCredentials');
    }
    if (text.contains('user-not-found')) {
      return AdminLocaleController.globalT('errors.auth.userNotFound');
    }
    if (text.contains('network-request-failed')) {
      return AdminLocaleController.globalT('errors.auth.networkFailed');
    }
    return AdminLocaleController.globalT('errors.auth.signInUnavailable');
  }

  @override
  Future<void> close() async {
    await _authSubscription.cancel();
    return super.close();
  }
}
