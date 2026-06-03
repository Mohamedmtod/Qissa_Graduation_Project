import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:perfume_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:perfume_app/features/auth/presentation/states/forgot_password_state.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late ForgotPasswordCubit forgotPasswordCubit;

  setUp(() {
    authRepository = MockAuthRepository();
    forgotPasswordCubit = ForgotPasswordCubit(authRepository: authRepository);
  });

  Widget wrap(Widget child, {String locale = 'en'}) {
    return MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: forgotPasswordCubit,
        child: child,
      ),
    );
  }

  group('ForgotPasswordPage Widget Tests', () {
    testWidgets('email step validation - invalid email', (tester) async {
      await tester.pumpWidget(wrap(const ForgotPasswordPage()));
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'not-an-email');
      
      // Find the button with text "Send Reset Code" (btnSendResetLink)
      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('transitions to OTP step on success', (tester) async {
      when(() => authRepository.requestPasswordResetOtp(any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(wrap(const ForgotPasswordPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();

      // Check if description for OTP step is shown
      expect(find.text('Enter the code sent to your email.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6)); // 6 OTP digit fields
    });

    testWidgets('OTP step validation - invalid code length', (tester) async {
      await tester.pumpWidget(wrap(const ForgotPasswordPage()));
      await tester.pumpAndSettle();

      // Trigger transition to OTP step
      forgotPasswordCubit.emit(const ForgotPasswordCodeSent('test@example.com'));
      await tester.pumpAndSettle();

      // Enter 3 digits
      final otpFields = find.byType(TextFormField);
      await tester.enterText(otpFields.at(0), '1');
      await tester.enterText(otpFields.at(1), '2');
      await tester.enterText(otpFields.at(2), '3');
      
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('6-digit code'), findsOneWidget); // Hint text used as error in _validateOtp
    });

    testWidgets('password step validation - mismatch', (tester) async {
      await tester.pumpWidget(wrap(const ForgotPasswordPage()));
      await tester.pumpAndSettle();

      // Trigger listener to move to password step
      forgotPasswordCubit.emit(ForgotPasswordOtpVerified());
      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      await tester.enterText(passwordFields.at(0), 'Password123!');
      await tester.enterText(passwordFields.at(1), 'Different123!');

      // Tap the submit button (SignOutInButton)
      await tester.tap(find.byType(SignOutInButton));
      await tester.pumpAndSettle();

      // Should show validation error on the field, not snackbar, because form validation fails first
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('resend cooldown label behavior', (tester) async {
      when(() => authRepository.requestPasswordResetOtp(any()))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(wrap(const ForgotPasswordPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pumpAndSettle();

      // After transition to OTP, resend cooldown starts at 60s
      expect(find.textContaining('Resend code (60 s)'), findsOneWidget);
      
      // Fast forward time
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resend code (59 s)'), findsOneWidget);
    });
  });
}
