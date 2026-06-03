import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/cubit/registration_cubit.dart';
import 'package:perfume_app/features/auth/presentation/pages/registration_page.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late RegistrationCubit registrationCubit;

  setUp(() {
    authRepository = MockAuthRepository();
    registrationCubit = RegistrationCubit(authRepository: authRepository);
  });

  tearDown(() => registrationCubit.close());

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(value: registrationCubit, child: child),
    );
  }

  testWidgets(
    'shows only the live password rule when password is missing a digit',
    (tester) async {
      await tester.pumpWidget(wrap(const RegistrationPage()));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mo');
      await tester.enterText(fields.at(1), 'Ali');
      await tester.enterText(fields.at(2), 'mo@example.com');
      await tester.enterText(fields.at(3), 'Password!');
      await tester.enterText(fields.at(4), 'Password!');

      await tester.tap(find.byType(SignOutInButton));
      await tester.pump();

      expect(find.text(PasswordErrorMessages.digit), findsOneWidget);
      verifyNever(
        () => authRepository.createEmailAndPassword(any(), any(), any(), any()),
      );
    },
  );
}
