import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/core/utils/input_formatters.dart';
import 'package:perfume_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:perfume_app/features/auth/presentation/states/forgot_password_state.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/custom_text_field.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/password_validation_rules.dart';
import 'package:perfume_app/widgets/password_visibility_icon.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpDigitControllers = List.generate(
    6,
    (_) => TextEditingController(text: '\u200B'),
  );
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ForgotPasswordStep _step = ForgotPasswordStep.email;
  bool _isNewPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  String _password = '';
  Timer? _resendTimer;
  int _resendCooldownSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    for (final controller in _otpDigitControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    switch (_step) {
      case ForgotPasswordStep.email:
        context.read<ForgotPasswordCubit>().requestResetCode(
          _emailController.text,
        );
        return;
      case ForgotPasswordStep.otp:
        context.read<ForgotPasswordCubit>().verifyOtp(
          email: _emailController.text,
          otp: _otpController.text,
        );
        return;
      case ForgotPasswordStep.password:
        if (!_isPasswordReadyForSubmit()) return;

        final l10n = AppLocalizations.of(context);
        if (_newPasswordController.text != _confirmPasswordController.text) {
          AppSnackBar.showError(context, l10n.msgNewPasswordsDoNotMatch);
          return;
        }
        context.read<ForgotPasswordCubit>().confirmReset(
          email: _emailController.text,
          otp: _otpController.text,
          newPassword: _newPasswordController.text,
        );
        return;
    }
  }

  bool _isPasswordReadyForSubmit() {
    if (validateRegPass(_newPasswordController.text) == null) return true;

    if (_password != _newPasswordController.text) {
      setState(() => _password = _newPasswordController.text);
    }
    return false;
  }

  String? _validatePasswordField(String? pass) {
    return (pass ?? '').isEmpty ? validateRegPass(pass) : null;
  }

  void _resendCode() {
    if (validateEmail(_emailController.text) != null) return;
    context.read<ForgotPasswordCubit>().requestResetCode(_emailController.text);
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldownSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds--);
    });
  }

  void _resetOtpInputs() {
    _otpController.clear();
    for (final controller in _otpDigitControllers) {
      controller.text = '\u200B';
    }
  }

  void _syncOtpController() {
    _otpController.text = _otpDigitControllers
        .map((controller) => controller.text.replaceAll('\u200B', ''))
        .join();
  }

  void _submitOtpIfComplete(FormFieldState<String> field) {
    if (_step != ForgotPasswordStep.otp) return;
    if (_otpController.text.length != _otpDigitControllers.length) return;
    if (!field.validate()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step != ForgotPasswordStep.otp) return;
      context.read<ForgotPasswordCubit>().verifyOtp(
        email: _emailController.text,
        otp: _otpController.text,
      );
    });
  }

  void _fillOtpDigits(String digits, int startIndex) {
    final sanitized = digits.replaceAll(RegExp(r'\D'), '');
    for (var offset = 0; offset < sanitized.length; offset++) {
      final targetIndex = startIndex + offset;
      if (targetIndex >= _otpDigitControllers.length) break;
      _otpDigitControllers[targetIndex].text = '\u200B${sanitized[offset]}';
    }
    _syncOtpController();

    final nextIndex = (startIndex + sanitized.length).clamp(
      0,
      _otpFocusNodes.length - 1,
    );
    if (_otpController.text.length == _otpDigitControllers.length) {
      _otpFocusNodes.last.unfocus();
    } else {
      _otpFocusNodes[nextIndex].requestFocus();
    }
  }

  void _handleOtpChanged(
    int index,
    String value,
    FormFieldState<String> field,
  ) {
    String englishValue = value;
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabic.length; i++) {
      englishValue = englishValue.replaceAll(arabic[i], i.toString());
    }
    final sanitized = englishValue.replaceAll(RegExp(r'\D'), '');

    if (sanitized.length > 1) {
      int startIdx = index;
      String toFill = sanitized;
      if (sanitized.length >= 6) {
        startIdx = 0;
        if (sanitized.length > 6) {
          toFill = sanitized.substring(sanitized.length - 6);
        }
      }
      _fillOtpDigits(toFill, startIdx);
    } else {
      _otpDigitControllers[index].value = TextEditingValue(
        text: '\u200B$sanitized',
        selection: TextSelection.collapsed(offset: sanitized.length + 1),
      );
      _syncOtpController();

      if (sanitized.isEmpty) {
        if (value.isEmpty && index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
        }
      } else if (index < _otpFocusNodes.length - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    }

    field.didChange(_otpController.text);
    if (field.hasError) {
      field.validate();
    }
    _submitOtpIfComplete(field);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Transform.scale(
            scaleX: Directionality.of(context) == TextDirection.rtl ? -1 : 1,
            child: const Icon(Icons.arrow_back_ios_new),
          ),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: () => _step == ForgotPasswordStep.email
              ? context.pop()
              : setState(() {
                  _step = _step == ForgotPasswordStep.password
                      ? ForgotPasswordStep.otp
                      : ForgotPasswordStep.email;
                }),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceBright,
      body: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordCodeSent) {
            _emailController.text = state.email;
            _resetOtpInputs();
            setState(() => _step = ForgotPasswordStep.otp);
            _startResendCooldown();
            AppSnackBar.showSuccess(context, l10n.msgResetCodeSentGeneric);
          } else if (state is ForgotPasswordSuccess) {
            AppSnackBar.showSuccess(context, l10n.msgPasswordUpdated);
            context.go('/login');
          } else if (state is ForgotPasswordOtpVerified) {
            setState(() => _step = ForgotPasswordStep.password);
          } else if (state is ForgotPasswordFailure) {
            AppSnackBar.showError(
              context,
              resolveUserFacingMessage(
                context,
                state.message,
                fallback: _fallbackForStep(state.step),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ForgotPasswordLoading;
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CustomTextStyle(
                                text: l10n.labelResetPassword,
                                textColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                fontsize: 32,
                                bold: true,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _descriptionForStep(l10n),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 30),
                              ..._buildStepFields(isLoading),
                              const SizedBox(height: 20),
                              SignOutInButton(
                                hintText: isLoading
                                    ? l10n.msgSending
                                    : _buttonTextForStep(l10n),
                                hintColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface,
                                backGroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onPressed: isLoading ? null : _onSubmit,
                              ),
                              if (_step != ForgotPasswordStep.email) ...[
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed:
                                      isLoading || _resendCooldownSeconds > 0
                                      ? null
                                      : _resendCode,
                                  child: Text(
                                    _resendCooldownSeconds > 0
                                        ? '${l10n.btnResendCode} ($_resendCooldownSeconds s)'
                                        : l10n.btnResendCode,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildStepFields(bool isLoading) {
    switch (_step) {
      case ForgotPasswordStep.email:
        return [
          CustomTextField(
            hintText: AppLocalizations.of(context).hintEmail,
            hidden: false,
            paddingBottom: 20,
            controller: _emailController,
            validator: validateEmail,
            enabled: !isLoading,
            inputFormatters: [CustomInputFormatters.email],
            autofill: AutofillHints.email,
            maxLength: InputLimits.email,
            textInputAction: true,
            onFieldSubmitted: (_) => _onSubmit(),
          ),
        ];
      case ForgotPasswordStep.otp:
        return [_buildOtpFields(isLoading)];
      case ForgotPasswordStep.password:
        return [
          CustomTextField(
            hintText: AppLocalizations.of(context).hintEnterNewPassword,
            hidden: _isNewPasswordHidden,
            controller: _newPasswordController,
            validator: _validatePasswordField,
            enabled: !isLoading,
            autofill: AutofillHints.newPassword,
            maxLength: InputLimits.password,
            onChanged: (value) => setState(() => _password = value),
            suffixIcon: PasswordVisibilityIcon(
              isHidden: _isNewPasswordHidden,
              onPressed: () {
                setState(() {
                  _isNewPasswordHidden = !_isNewPasswordHidden;
                });
              },
            ),
          ),
          _password.isEmpty
              ? const SizedBox(height: 0)
              : const SizedBox(height: 10),
          PasswordValidationRules(password: _password),
          const SizedBox(height: 20),
          CustomTextField(
            hintText: AppLocalizations.of(context).hintReenterNewPassword,
            hidden: _isConfirmPasswordHidden,
            controller: _confirmPasswordController,
            validator: (value) =>
                confirmPasswordValidator(value, _newPasswordController),
            enabled: !isLoading,
            autofill: AutofillHints.newPassword,
            maxLength: InputLimits.password,
            textInputAction: true,
            onFieldSubmitted: (_) => _onSubmit(),
            suffixIcon: PasswordVisibilityIcon(
              isHidden: _isConfirmPasswordHidden,
              onPressed: () {
                setState(() {
                  _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
                });
              },
            ),
          ),
        ];
    }
  }

  String? _validateOtp(String? value) {
    final otp = (value ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return AppLocalizations.of(context).hintResetCode;
    }
    return null;
  }

  String _descriptionForStep(AppLocalizations l10n) {
    switch (_step) {
      case ForgotPasswordStep.email:
        return l10n.msgResetCodeInstructions;
      case ForgotPasswordStep.otp:
        return l10n.msgEnterResetCodeInstructions;
      case ForgotPasswordStep.password:
        return l10n.msgChooseNewPasswordInstructions;
    }
  }

  String _buttonTextForStep(AppLocalizations l10n) {
    switch (_step) {
      case ForgotPasswordStep.email:
        return l10n.btnSendResetLink;
      case ForgotPasswordStep.otp:
        return l10n.btnContinue;
      case ForgotPasswordStep.password:
        return l10n.btnUpdatePassword;
    }
  }

  String _fallbackForStep(ForgotPasswordStep step) {
    switch (step) {
      case ForgotPasswordStep.email:
        return AppLocalizations.of(context).msgResetCodeSendFailed;
      case ForgotPasswordStep.otp:
      case ForgotPasswordStep.password:
        return AppLocalizations.of(context).msgInvalidOrExpiredCode;
    }
  }

  Widget _buildOtpFields(bool isLoading) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: FormField<String>(
        validator: (_) => _validateOtp(_otpController.text),
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: List.generate(_otpDigitControllers.length * 2 - 1, (
                    i,
                  ) {
                    if (i.isOdd) return const SizedBox(width: 8);
                    final index = i ~/ 2;
                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: TextFormField(
                          textAlignVertical: TextAlignVertical.center,
                          controller: _otpDigitControllers[index],
                          focusNode: _otpFocusNodes[index],
                          enabled: !isLoading,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '',
                            counterText: '',
                            filled: true,
                            fillColor: !isLoading
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLowest
                                : lightGray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: field.hasError
                                    ? red
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLowest,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: field.hasError
                                    ? red
                                    : Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: red,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) =>
                              _handleOtpChanged(index, value, field),
                          onTap: () {
                            if (_otpDigitControllers[index].text.isEmpty) {
                              _otpDigitControllers[index].text = '\u200B';
                            }
                            _otpDigitControllers[index].selection =
                                TextSelection(
                                  baseOffset: 1,
                                  extentOffset:
                                      _otpDigitControllers[index].text.length,
                                );
                          },
                          onFieldSubmitted: (_) {
                            if (index == _otpDigitControllers.length - 1) {
                              _onSubmit();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (field.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  field.errorText ?? l10n.hintResetCode,
                  style: const TextStyle(
                    color: red,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
