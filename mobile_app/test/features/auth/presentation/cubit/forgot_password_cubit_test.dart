import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:perfume_app/features/auth/presentation/states/forgot_password_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
  });

  group('ForgotPasswordCubit', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits loading then code sent when OTP request succeeds',
      build: () {
        when(
          () => authRepository.requestPasswordResetOtp(any()),
        ).thenAnswer((_) async => null);
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.requestResetCode(' user@example.com '),
      expect: () => [
        const ForgotPasswordLoading(ForgotPasswordStep.email),
        const ForgotPasswordCodeSent('user@example.com'),
      ],
      verify: (_) {
        verify(
          () => authRepository.requestPasswordResetOtp(' user@example.com '),
        ).called(1);
      },
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits failure when OTP request fails',
      build: () {
        when(
          () => authRepository.requestPasswordResetOtp(any()),
        ).thenAnswer((_) async => 'Too many attempts. Try again later.');
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.requestResetCode('user@example.com'),
      expect: () => [
        const ForgotPasswordLoading(ForgotPasswordStep.email),
        const ForgotPasswordFailure(
          'Too many attempts. Try again later.',
          ForgotPasswordStep.email,
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits loading then verified when OTP verification succeeds',
      build: () {
        when(
          () => authRepository.verifyPasswordResetOtp(
            email: any(named: 'email'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => null);
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.verifyOtp(
        email: 'user@example.com',
        otp: '123456',
      ),
      expect: () => [
        const ForgotPasswordLoading(ForgotPasswordStep.otp),
        ForgotPasswordOtpVerified(),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits OTP failure when worker rejects invalid code',
      build: () {
        when(
          () => authRepository.verifyPasswordResetOtp(
            email: any(named: 'email'),
            otp: any(named: 'otp'),
          ),
        ).thenAnswer((_) async => 'Invalid or expired code.');
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.verifyOtp(
        email: 'user@example.com',
        otp: '000000',
      ),
      expect: () => [
        const ForgotPasswordLoading(ForgotPasswordStep.otp),
        const ForgotPasswordFailure(
          'Invalid or expired code.',
          ForgotPasswordStep.otp,
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits success when password reset confirmation succeeds',
      build: () {
        when(
          () => authRepository.confirmPasswordResetOtp(
            email: any(named: 'email'),
            otp: any(named: 'otp'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async => null);
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.confirmReset(
        email: 'user@example.com',
        otp: '123456',
        newPassword: 'Strong1!',
      ),
      expect: () => [
        const ForgotPasswordLoading(ForgotPasswordStep.password),
        ForgotPasswordSuccess(),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emits password-step failure when worker rejects weak password',
      build: () {
        when(
          () => authRepository.confirmPasswordResetOtp(
            email: any(named: 'email'),
            otp: any(named: 'otp'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async => 'Password must be at least 8 characters long.');
        return ForgotPasswordCubit(authRepository: authRepository);
      },
      act: (cubit) => cubit.confirmReset(
        email: 'user@example.com',
        otp: '123456',
        newPassword: 'weak',
      ),
      expect: () => [
        const ForgotPasswordFailure(
          'Password must be at least 8 characters long.',
          ForgotPasswordStep.password,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => authRepository.confirmPasswordResetOtp(
            email: any(named: 'email'),
            otp: any(named: 'otp'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );
  });
}
