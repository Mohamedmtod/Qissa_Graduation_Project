import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_snack_bar.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/admin_ui.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCFAF6), Color(0xFFF3ECE6), Color(0xFFF8F6F2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 900;

                    if (stacked) {
                      return Column(
                        children: const [
                          _LoginEditorialPanel(),
                          SizedBox(height: 24),
                          _LoginFormPanel(),
                        ],
                      );
                    }

                    return const Row(
                      children: [
                        Expanded(flex: 6, child: _LoginEditorialPanel()),
                        SizedBox(width: 24),
                        Expanded(flex: 5, child: _LoginFormPanel()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginEditorialPanel extends StatelessWidget {
  const _LoginEditorialPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return SizedBox(
      height: 620,
      child: Stack(
        children: [
          const Positioned.fill(
            child: AdminNetworkImage(
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCvezjXEkgvJwSPPndhvN9rQCJMKZV_uvJOrh3ibXpo8EkF21Wzk2X4SQ0Qrmq9aORq-_knFJCiwwnya-K9Bk2HGXQWOaN0kxSSSWeucr5GMD0EQrzWGNMDyPIzl6zAKyURvpYra_7SR-gyAKZ0kFouPvNJyHQ5tebypjKLMd4YQz28XxG1egoVW9XWsRFi54p-sDzUZQpgyk_7vESlqBgXdhpdix0WOgEsIw25t0IAjS1EKS6aFK44gh-Jznok0AEpv8S6A51FnSk',
              width: double.infinity,
              height: double.infinity,
              borderRadius: 32,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xF0181716),
                    Color(0x7A181716),
                    Color(0x14181716),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminSectionLabel(
                  label: l10n.t('login.badge'),
                  color: AppTheme.primaryFixed,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('login.brandTitle'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 44,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('login.editorialDescription'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormPanel extends StatefulWidget {
  const _LoginFormPanel();

  @override
  State<_LoginFormPanel> createState() => _LoginFormPanelState();
}

class _LoginFormPanelState extends State<_LoginFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AdminLocaleController>();
    return BlocConsumer<AdminAuthCubit, AdminAuthState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          AdminSnackBar.error(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AdminAuthViewStatus.loading;

        return AdminSurfaceCard(
          padding: const EdgeInsets.all(28),
          borderRadius: 32,
          color: Colors.white.withValues(alpha: 0.78),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('login.title'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.primary,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('login.subtitle'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.t('login.emailLabel'),
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.t('login.emailValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('login.passwordLabel'),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.t('login.passwordValidation');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AdminPrimaryButton(
                    label: isLoading
                        ? l10n.t('login.loadingButton')
                        : l10n.t('login.submit'),
                    icon: isLoading ? null : Icons.login,
                    onPressed: isLoading
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }

                            context.read<AdminAuthCubit>().signIn(
                              email: _emailController.text,
                              password: _passwordController.text,
                            );
                          },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t('login.footnote'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
