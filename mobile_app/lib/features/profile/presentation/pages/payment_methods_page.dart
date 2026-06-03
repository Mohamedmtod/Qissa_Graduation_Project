import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/localization/user_facing_message_resolver.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_cubit.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_state.dart';
import 'package:perfume_app/features/profile/presentation/pages/profile_page.dart'
    show CustomProContainer;
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/core/utils/app_snack_bar.dart';
import 'package:perfume_app/widgets/skeletons.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
        title: CustomTextStyle(
          text: l10n.labelPaymentMethods,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<UserCubit, UserState>(
          listener: (context, state) {
            if (state is UserUpdateSuccess) {
              AppSnackBar.showSuccess(context, l10n.msgSuccess);
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
            final user = _extractUser(state);

            if (state is UserInitial ||
                (state is UserLoading && user == null)) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ProfileHeaderSkeleton(),
                      SizedBox(height: 24),
                      SkeletonBox(
                        width: double.infinity,
                        height: 200,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is UserEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CustomTextStyle(
                    text: l10n.msgProfileLoadFailed,
                    fontsize: 14,
                    textColor: Colors.grey,
                    bold: false,
                  ),
                ),
              );
            }

            if (user == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CustomTextStyle(
                    text: l10n.msgProfileLoadFailed,
                    fontsize: 14,
                    textColor: Colors.grey,
                    bold: false,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextStyle(
                    text: l10n.msgManagePaymentOptions,
                    fontsize: 13,
                    textColor: Colors.grey,
                    bold: false,
                  ),
                  const SizedBox(height: 16),
                  CustomProContainer(
                    topLeftRadius: 12,
                    topRightRadius: 12,
                    bottomLeftRadius: 12,
                    bottomRightRadius: 12,
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextStyle(
                                text: l10n.labelCashOnDelivery,
                                fontsize: 16,
                                textColor: Theme.of(context).colorScheme.onSurface,
                                bold: true,
                              ),
                              const SizedBox(height: 4),
                              CustomTextStyle(
                                text: l10n.msgDefaultPaymentMethod,
                                fontsize: 12,
                                textColor: Colors.grey,
                                bold: false,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static UserModel? _extractUser(UserState state) {
    if (state is UserLoaded) return state.user;
    if (state is UserUpdating) return state.user;
    if (state is UserUpdateSuccess) return state.user;
    if (state is UserError) return state.user;
    return null;
  }
}
