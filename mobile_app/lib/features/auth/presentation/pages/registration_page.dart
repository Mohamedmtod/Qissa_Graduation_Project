import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/core/utils/input_formatters.dart';
import 'package:perfume_app/features/auth/presentation/cubit/registration_cubit.dart';
import 'package:perfume_app/features/auth/presentation/states/registration_state.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';
import 'package:perfume_app/widgets/custom_text_field.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';
import 'package:perfume_app/widgets/password_visibility_icon.dart';
import 'package:perfume_app/widgets/password_validation_rules.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    this.returnTo,
    this.backTo,
    this.tabIndex,
  });

  final String? returnTo;
  final String? backTo;
  final int? tabIndex;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  String password = '';

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void onRegisterPressed() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPasswordReadyForSubmit()) return;

    context.read<RegistrationCubit>().register(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      email: emailController.text,
      password: passwordController.text,
    );
  }

  bool _isPasswordReadyForSubmit() {
    if (validateRegPass(passwordController.text) == null) return true;

    if (password != passwordController.text) {
      setState(() => password = passwordController.text);
    }
    return false;
  }

  String? _validatePasswordField(String? pass) {
    return (pass ?? '').isEmpty ? validateRegPass(pass) : null;
  }

  VoidCallback _backAction() {
    final backTo = _safeAppPath(widget.backTo);
    if (backTo == null) return navigateToWelcome(context);
    return () => context.go(backTo);
  }

  void _goAfterRegister() {
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
    final h = MediaQuery.of(context).size.height;

    final gap = (h * 0.1).clamp(14.0, 30.0);
    final bigGap = (h * 0.038).clamp(20.0, 40.0);
    final double radius = 16;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: _backAction(),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceBright,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: BlocConsumer<RegistrationCubit, RegisterState>(
                      listener: (context, state) {
                        if (state is RegisterSuccess) {
                          _goAfterRegister();
                        } else if (state is RegisterFailure) {
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
                        final isLoading = state is RegisterLoading;
                        return Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CustomTextStyle(
                                text: l10n.btnRegister,
                                textColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontsize: 32,
                                bold: true,
                              ),

                              SizedBox(height: bigGap),

                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      hintText: l10n.hintFirstName,
                                      hidden: false,
                                      paddingBottom: 0,
                                      paddingTop: 0,
                                      autofill: AutofillHints.givenName,
                                      maxLength: InputLimits.firstName,
                                      controller: firstNameController,
                                      validator: nameValidator,
                                      enabled: !isLoading,
                                      inputFormatters: [
                                        CustomInputFormatters.name,
                                      ],
                                      radius: radius,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CustomTextField(
                                      hintText: l10n.hintLastName,
                                      hidden: false,
                                      autofill: AutofillHints.familyName,
                                      maxLength: InputLimits.lastName,
                                      controller: lastNameController,
                                      validator: nameValidator,
                                      enabled: !isLoading,
                                      inputFormatters: [
                                        CustomInputFormatters.name,
                                      ],
                                      radius: radius,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: gap),

                              CustomTextField(
                                hintText: l10n.hintEmail,
                                hidden: false,
                                autofill: AutofillHints.email,
                                maxLength: InputLimits.email,
                                controller: emailController,
                                validator: validateEmail,
                                enabled: !isLoading,
                                inputFormatters: [CustomInputFormatters.email],
                                radius: radius,
                              ),

                              SizedBox(height: gap),

                              CustomTextField(
                                hintText: l10n.hintPassword,
                                hidden: _isPasswordHidden,
                                autofill: AutofillHints.newPassword,
                                maxLength: InputLimits.password,
                                controller: passwordController,
                                validator: _validatePasswordField,
                                enabled: !isLoading,
                                onChanged: (val) =>
                                    setState(() => password = val),
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
                              password.isEmpty
                                  ? const SizedBox(height: 0)
                                  : const SizedBox(height: 10),
                              PasswordValidationRules(password: password),

                              SizedBox(height: gap),

                              CustomTextField(
                                hintText: l10n.hintConfirmPassword,
                                hidden: _isConfirmPasswordHidden,
                                autofill: AutofillHints.newPassword,
                                maxLength: InputLimits.password,
                                textInputAction: true,
                                controller: confirmPasswordController,
                                validator: (pass) => confirmPasswordValidator(
                                  pass,
                                  passwordController,
                                ),
                                onFieldSubmitted: (_) => onRegisterPressed(),
                                enabled: !isLoading,
                                suffixIcon: PasswordVisibilityIcon(
                                  isHidden: _isConfirmPasswordHidden,
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordHidden =
                                          !_isConfirmPasswordHidden;
                                    });
                                  },
                                ),
                                radius: radius,
                              ),
                              SizedBox(height: bigGap),
                              SignOutInButton(
                                hintText: isLoading
                                    ? l10n.msgCreatingAccount
                                    : l10n.btnRegister,
                                hintColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                backGroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onPressed: isLoading ? null : onRegisterPressed,

                                paddingBottom: bigGap,
                                radius: radius,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
