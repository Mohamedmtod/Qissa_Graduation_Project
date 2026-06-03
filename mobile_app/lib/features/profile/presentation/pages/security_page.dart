import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/features/profile/presentation/pages/profile_page.dart'
    show CustomProContainer;

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _isSubmittingDeletion = false;

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
          text: l10n.labelSecurity,
          fontsize: 20,
          bold: true,
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/change-password'),
                child: CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextStyle(
                          text: l10n.labelChangePassword,
                          fontsize: 16,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          bold: true,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isSubmittingDeletion
                    ? null
                    : () => _confirmAccountDeletion(context),
                child: CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextStyle(
                              text: l10n.btnRequestAccountDeletion,
                              fontsize: 16,
                              textColor: Theme.of(context).colorScheme.onSurface,
                              bold: true,
                            ),
                            const SizedBox(height: 4),
                            CustomTextStyle(
                              text: l10n.securityDeleteAccountSubtitle,
                              fontsize: 12,
                              textColor: Colors.grey,
                              bold: false,
                            ),
                          ],
                        ),
                      ),
                      if (_isSubmittingDeletion)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAccountDeletion(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.securityDeleteAccountDialogTitle,
          ),
          content: Text(
            l10n.securityDeleteAccountDialogBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.btnCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.btnSubmitRequest,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isSubmittingDeletion = true);
    final error = await context.read<AuthRepository>().requestAccountDeletion();
    if (!context.mounted) return;
    setState(() => _isSubmittingDeletion = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? l10n.msgAccountDeletionSubmitted,
        ),
      ),
    );
  }

}
