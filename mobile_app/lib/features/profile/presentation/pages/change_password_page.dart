import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/widgets/custom_text_field.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/password_visibility_icon.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/features/auth/presentation/cubit/update_password_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordHidden = true;
  bool _isNewPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;
    context.read<UpdatePasswordCubit>().updatePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: CustomTextStyle(
          text: l10n.labelChangePassword,
          fontsize: 18,
          textColor: Theme.of(context).colorScheme.onSurface,
          bold: true,
        ),
        leading: GoBackIcon(
          navigateTo: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: BlocConsumer<UpdatePasswordCubit, UpdatePasswordState>(
            listener: (context, state) {
              if (state is UpdatePasswordSuccess) {
                AppSnackBar.showSuccess(context, l10n.msgPasswordUpdated);
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/MainLayout');
                }
              } else if (state is UpdatePasswordError) {
                AppSnackBar.showError(context, resolveUserFacingMessage(
                        context,
                        state.message,
                        fallback: l10n.msgPasswordUpdateFailed));
              }
            },
            builder: (context, state) {
              final isLoading = state is UpdatePasswordLoading;

              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    CustomTextStyle(
                      text: l10n.labelCurrentPassword,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _currentPasswordController,
                      hintText: l10n.hintEnterCurrentPassword,
                      hidden: _isCurrentPasswordHidden,
                      maxLength: InputLimits.password,
                      enabled: !isLoading,
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.msgRequiredField
                          : null,
                      autofill: AutofillHints.password,
                      suffixIcon: PasswordVisibilityIcon(
                        isHidden: _isCurrentPasswordHidden,
                        onPressed: () {
                          setState(() {
                            _isCurrentPasswordHidden =
                                !_isCurrentPasswordHidden;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    CustomTextStyle(
                      text: l10n.labelNewPassword,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _newPasswordController,
                      hintText: l10n.hintEnterNewPassword,
                      hidden: _isNewPasswordHidden,
                      maxLength: InputLimits.password,
                      enabled: !isLoading,
                      validator: validateRegPass,
                      autofill: AutofillHints.newPassword,
                      suffixIcon: PasswordVisibilityIcon(
                        isHidden: _isNewPasswordHidden,
                        onPressed: () {
                          setState(() {
                            _isNewPasswordHidden = !_isNewPasswordHidden;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    CustomTextStyle(
                      text: l10n.labelConfirmNewPassword,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      hintText: l10n.hintReenterNewPassword,
                      hidden: _isConfirmPasswordHidden,
                      maxLength: InputLimits.password,
                      enabled: !isLoading,
                      validator: (value) => confirmPasswordValidator(
                        value,
                        _newPasswordController,
                      ),
                      autofill: AutofillHints.newPassword,
                      suffixIcon: PasswordVisibilityIcon(
                        isHidden: _isConfirmPasswordHidden,
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordHidden =
                                !_isConfirmPasswordHidden;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _onSavePressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: white,
                                  strokeWidth: 2,
                                ),
                              )
                            : CustomTextStyle(
                                text: l10n.btnUpdatePassword,
                                fontsize: 16,
                                bold: true,
                                textColor: white,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
