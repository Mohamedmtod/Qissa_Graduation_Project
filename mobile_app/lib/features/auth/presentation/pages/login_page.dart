import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:perfume_app/features/auth/presentation/states/login_state.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';
import 'package:perfume_app/widgets/custom_text_field.dart';
import 'package:perfume_app/widgets/password_visibility_icon.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/core/utils/input_formatters.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.returnTo, this.backTo, this.tabIndex});

  final String? returnTo;
  final String? backTo;
  final int? tabIndex;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isPasswordHidden = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void onLoginPressed() {
    if (!_formKey.currentState!.validate()) return;

    context.read<LoginCubit>().login(
      email: emailController.text.trim(),
      password: passwordController.text,
    );
  }

  VoidCallback _backAction() {
    final backTo = _safeAppPath(widget.backTo);
    if (backTo == null) return navigateToWelcome(context);
    return () => context.go(backTo);
  }

  void _goAfterLogin() {
    final tabIndex = widget.tabIndex;
    if (tabIndex != null && tabIndex >= 0 && tabIndex <= 4) {
      context.read<LayoutCubit>().changeIndex(tabIndex);
    }

    final returnTo = _safeAppPath(widget.returnTo);
    if (returnTo == null) {
      navigateToMainLayout(context, tabIndex ?? Go.home)();
      return;
    }
    context.go(returnTo);
  }

  String? _safeAppPath(String? value) {
    final path = value?.trim();
    if (path == null || path.isEmpty) return null;
    if (!path.startsWith('/') || path.startsWith('//')) return null;
    if (path.startsWith('/login') || path.startsWith('/register')) return null;
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double radius = 16;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backAction()();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: GoBackIcon(navigateTo: _backAction()),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceBright,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: BlocConsumer<LoginCubit, LoginState>(
                    listener: (context, state) {
                      if (state is LoginSuccess) {
                        _goAfterLogin();
                      } else if (state is LoginFailure) {
                        AppSnackBar.showInfo(
                          context,
                          resolveUserFacingMessage(
                            context,
                            state.message,
                            fallback: l10n.msgGenericTryAgainLater,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      final isLoading = state is LoginLoading;

                      return Form(
                        key: _formKey,
                        child: SizedBox(
                          width: 500,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextStyle(
                                text: l10n.loginWelcomeBack,
                                textColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontsize: 28,
                                bold: true,
                                maxLines: 3,
                              ),
                              CustomTextStyle(
                                text: l10n.loginSubtitle,
                                textColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontsize: 24,
                                bold: false,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                key: const ValueKey('login_email_field'),
                                hintText: l10n.hintEmail,
                                hidden: false,
                                paddingBottom: 20,
                                paddingTop: 0,
                                autofill: AutofillHints.email,
                                maxLength: InputLimits.email,
                                controller: emailController,
                                validator: validateEmail,
                                enabled: !isLoading,
                                inputFormatters: [CustomInputFormatters.email],
                                radius: radius,
                              ),
                              CustomTextField(
                                key: const ValueKey('login_password_field'),
                                hintText: l10n.hintPassword,
                                hidden: _isPasswordHidden,
                                paddingBottom: 15,
                                autofill: AutofillHints.password,
                                maxLength: InputLimits.password,
                                controller: passwordController,
                                onFieldSubmitted: (_) => onLoginPressed(),
                                validator: validateLoginPass,
                                textInputAction: true,
                                enabled: !isLoading,
                                suffixIcon: PasswordVisibilityIcon(
                                  isHidden: _isPasswordHidden,
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordHidden = !_isPasswordHidden;
                                    });
                                  },
                                ),
                                radius: radius,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: navigateToForgotPassword(context),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 12.0,
                                      bottom: 12.0,
                                      right: 24.0,
                                    ),
                                    child: CustomTextStyle(
                                      text: l10n.btnForgotPassword,
                                      textColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontsize: 16,
                                      bold: true,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 30,
                                  bottom: 10,
                                ),
                                child: SignOutInButton(
                                  key: const ValueKey('login_submit_button'),
                                  hintText: isLoading
                                      ? l10n.msgLoggingIn
                                      : l10n.btnLogin,
                                  hintColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLowest,
                                  backGroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  onPressed: isLoading ? null : onLoginPressed,
                                  paddingLeft: 0,
                                  paddingRight: 0,
                                  radius: radius,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomTextStyle(
                                    text: l10n.msgDontHaveAccount,
                                    textColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontsize: 12,
                                    bold: false,
                                  ),

                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: navigateToRegistrationWithReturn(
                                      context,
                                      returnTo: widget.returnTo,
                                      backTo: widget.backTo,
                                      tabIndex: widget.tabIndex,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                      ),
                                      child: CustomTextStyle(
                                        text: l10n.btnCreateAccount,
                                        textColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontsize: 12,
                                        bold: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
