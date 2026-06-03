import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/features/profile/presentation/pages/profile_page.dart'
    show CustomProContainer;
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/localization/locale_cubit.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/MainLayout');
            }
          },
        ),
        title: CustomTextStyle(
          text: l10n.language,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<LocaleCubit, Locale>(
            builder: (context, currentLocale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.read<LocaleCubit>().changeLocale(
                      const Locale('en'),
                    ),
                    child: CustomProContainer(
                      topLeftRadius: 12,
                      topRightRadius: 12,
                      bottomLeftRadius: 12,
                      bottomRightRadius: 12,
                      child: Row(
                        children: [
                          CustomTextStyle(
                            text: l10n.english,
                            fontsize: 16,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const Spacer(),
                          if (currentLocale.languageCode == 'en')
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.read<LocaleCubit>().changeLocale(
                      const Locale('ar'),
                    ),
                    child: CustomProContainer(
                      topLeftRadius: 12,
                      topRightRadius: 12,
                      bottomLeftRadius: 12,
                      bottomRightRadius: 12,
                      child: Row(
                        children: [
                          CustomTextStyle(
                            text: l10n.arabic,
                            fontsize: 16,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const Spacer(),
                          if (currentLocale.languageCode == 'ar')
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
