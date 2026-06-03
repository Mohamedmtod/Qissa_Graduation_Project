import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../data/repos/pos_repository.dart';

class CashSessionState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? activeSession;

  CashSessionState({
    required this.isLoading,
    this.errorMessage,
    this.activeSession,
  });

  factory CashSessionState.initial() {
    return CashSessionState(isLoading: false);
  }

  CashSessionState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? activeSession,
    bool clearSession = false,
  }) {
    return CashSessionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeSession: clearSession ? null : (activeSession ?? this.activeSession),
    );
  }
}

class CashSessionCubit extends Cubit<CashSessionState> {
  final PosRepository _repository;

  CashSessionCubit(this._repository) : super(CashSessionState.initial());

  Future<void> loadCurrentSession() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final res = await _repository.getCurrentCashSession();
      debugPrint('[CashSessionCubit] getCurrentCashSession result: $res');
      if (res['active'] == true) {
        emit(state.copyWith(
          isLoading: false,
          activeSession: res['session'] as Map<String, dynamic>?,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          clearSession: true,
        ));
      }
    } catch (e) {
      debugPrint('[CashSessionCubit] loadCurrentSession error: $e');
      if (e is DioException) {
        debugPrint('[CashSessionCubit] loadCurrentSession response data: ${e.response?.data}');
      }
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch session status: $e',
      ));
    }
  }

  Future<void> openSession(double openingCash, String? notes) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final res = await _repository.openCashSession(openingCash: openingCash, notes: notes);
      debugPrint('[CashSessionCubit] openSession result: $res');
      if (res['ok'] == true) {
        await loadCurrentSession();
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to open session',
        ));
      }
    } catch (e) {
      debugPrint('[CashSessionCubit] openSession error: $e');
      if (e is DioException) {
        debugPrint('[CashSessionCubit] openSession response data: ${e.response?.data}');
      }
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Error opening session: $e',
      ));
    }
  }

  Future<void> closeSession(double actualCash, String? notes) async {
    final session = state.activeSession;
    if (session == null) return;
    final sessionId = session['id'] as String;

    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final res = await _repository.closeCashSession(
        sessionId: sessionId,
        actualCash: actualCash,
        notes: notes,
      );
      if (res['ok'] == true) {
        emit(state.copyWith(
          isLoading: false,
          clearSession: true,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to close session',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Error closing session: $e',
      ));
    }
  }
}
