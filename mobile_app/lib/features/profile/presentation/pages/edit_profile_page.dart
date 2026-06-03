import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/core/utils/validator.dart';
import 'package:perfume_app/core/utils/input_formatters.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_cubit.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_state.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/widgets/custom_text_field.dart';
import 'package:perfume_app/widgets/icons/go_back_icon.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel? user;
  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.user?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.user?.lastName ?? '',
    );
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate() && widget.user != null) {
      final updatedUser = widget.user!.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      context.read<UserCubit>().updateUserProfile(updatedUser);
    }
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
          text: l10n.labelEditProfile,
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
          padding: const EdgeInsets.all(16.0),
          child: BlocConsumer<UserCubit, UserState>(
            listener: (context, state) {
              if (state is UserUpdateSuccess) {
                AppSnackBar.showSuccess(context, l10n.msgProfileUpdated);
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/MainLayout');
                }
              } else if (state is UserError) {
                AppSnackBar.showError(
                  context,
                  resolveUserFacingMessage(
                    context,
                    state.message,
                    fallback: l10n.msgProfileUpdateFailed,
                  ),
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is UserUpdating;
              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    CustomTextStyle(
                      text: l10n.labelFirstName,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _firstNameController,
                      hintText: l10n.hintEnterFirstName,
                      hidden: false,
                      autofill: null,
                      maxLength: 50,
                      validator: nameValidator,
                      inputFormatters: [CustomInputFormatters.name],
                    ),
                    const SizedBox(height: 16),

                    CustomTextStyle(
                      text: l10n.labelLastName,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _lastNameController,
                      hintText: l10n.hintEnterLastName,
                      hidden: false,
                      autofill: null,
                      maxLength: 50,
                      validator: nameValidator,
                      inputFormatters: [CustomInputFormatters.name],
                    ),
                    const SizedBox(height: 16),

                    CustomTextStyle(
                      text: l10n.labelPhoneNumberOptional,
                      fontsize: 14,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      bold: true,
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _phoneController,
                      hintText: l10n.hintEnterPhoneNumber,
                      hidden: false,
                      autofill: null,
                      maxLength: 20,
                      validator: optionalPhoneValidator,
                      inputFormatters: [CustomInputFormatters.digitsOnly],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveProfile,
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
                                text: l10n.btnSaveChanges,
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
