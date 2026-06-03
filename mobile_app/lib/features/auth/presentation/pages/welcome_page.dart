import 'package:flutter/material.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/core/router/navigation_logic.dart';
import 'package:perfume_app/widgets/sign_out_in_button.dart';
import 'package:perfume_app/core/constants/static_images.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AppImages.welcomePageBackground,
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomTextStyle(
                  text: l10n.labelWelcomeTitle,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  fontsize: 24,
                  bold: true,
                ),

                SizedBox(height: 30),
                SignOutInButton(
                  key: const ValueKey('welcome_browse_guest_button'),
                  hintText: l10n.welcomeExploreProducts,
                  hintColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLowest,
                  backGroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: navigateToGuestBrowsing(context),
                  paddingLeft: 20,
                  paddingRight: 20,
                  radius: 16,
                ),
                SizedBox(height: 10),
                SignOutInButton(
                  key: const ValueKey('welcome_register_button'),
                  hintText: l10n.btnRegister,
                  hintColor: Theme.of(context).colorScheme.onSurface,
                  backGroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLowest,
                  onPressed: navigateToRegistration(context),
                  radius: 16,
                  paddingLeft: 20,
                  paddingRight: 20,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomTextStyle(
                      text: l10n.msgAlreadyHaveAccount,
                      textColor: Theme.of(context).colorScheme.onSurface,
                      fontsize: 16,
                      bold: false,
                    ),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: navigateToLogin(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4.0,
                        ),
                        child: CustomTextStyle(
                          text: l10n.btnLogin,
                          textColor: Theme.of(context).colorScheme.primary,
                          fontsize: 16,
                          bold: true,
                        ),
                      ),
                    ),
                  ],
                ),

                // Expanded(
                //   child: SignOutInButton(
                //     key: const ValueKey('welcome_login_button'),
                //     hintText: l10n.btnLogin,
                //     hintColor: Theme.of(context).colorScheme.onSurface,
                //     backGroundColor: white,
                //     onPressed: navigateToLogin(context),
                //     paddingRight: 20,
                //     paddingLeft: 4,
                //     radius: 16,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
