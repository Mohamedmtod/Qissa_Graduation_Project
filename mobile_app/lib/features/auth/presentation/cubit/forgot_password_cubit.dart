import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/states/forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final AuthRepository _authRepository;

  ForgotPasswordCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(ForgotPasswordInitial());

  Future<void> requestResetCode(String email) async {
    emit(const ForgotPasswordLoading(ForgotPasswordStep.email));
    final error = await _authRepository.requestPasswordResetOtp(email);

    if (error == null) {
      emit(ForgotPasswordCodeSent(email.trim()));
    } else {
      emit(ForgotPasswordFailure(error, ForgotPasswordStep.email));
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    emit(const ForgotPasswordLoading(ForgotPasswordStep.otp));
    final error = await _authRepository.verifyPasswordResetOtp(
      email: email,
      otp: otp,
    );

    if (error == null) {
      emit(ForgotPasswordOtpVerified());
    } else {
      emit(ForgotPasswordFailure(error, ForgotPasswordStep.otp));
    }
  }

  Future<void> confirmReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    // Local validation before worker call
    final localError = _validatePasswordLocally(newPassword);
    if (localError != null) {
      emit(ForgotPasswordFailure(localError, ForgotPasswordStep.password));
      return;
    }

    emit(const ForgotPasswordLoading(ForgotPasswordStep.password));
    final error = await _authRepository.confirmPasswordResetOtp(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );

    if (error == null) {
      emit(ForgotPasswordSuccess());
    } else {
      emit(ForgotPasswordFailure(error, ForgotPasswordStep.password));
    }
  }

  String? _validatePasswordLocally(String password) {
    return validateRegPass(password);
  }
}
