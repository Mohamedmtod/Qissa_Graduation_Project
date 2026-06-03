import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/widgets/custom_text_style.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_cubit.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_state.dart';
import 'package:perfume_app/l10n/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Color get backgroundColor2 => Theme.of(context).colorScheme.surfaceContainerLowest;
  Color get backgroundColor => Theme.of(context).colorScheme.surface;
  Color get gg => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authUser = context.select((AuthBloc b) => b.state.user);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,

                  child: BlocBuilder<UserCubit, UserState>(
                    builder: (context, state) {
                      String name = authUser?.displayName ?? '';
                      String mail = authUser?.email ?? '';

                      if (state is UserLoaded) {
                        name = '${state.user.firstName} ${state.user.lastName}'
                            .trim();
                        mail = state.user.email;
                      } else if (state is UserUpdating) {
                        name = '${state.user.firstName} ${state.user.lastName}'
                            .trim();
                        mail = state.user.email;
                      } else if (state is UserUpdateSuccess) {
                        name = '${state.user.firstName} ${state.user.lastName}'
                            .trim();
                        mail = state.user.email;
                      }

                      return MainProfile(
                        backgroundColor: backgroundColor,
                        helloText: l10n.labelHello,
                        username: name,
                        email: mail,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    //my orders
                    Expanded(
                      child: CustomProContainer(
                        topLeftRadius: 12,
                        topRightRadius: 12,
                        bottomLeftRadius: 12,
                        bottomRightRadius: 12,
                        onTap: () => context.push('/my-orders'),
                        width: double.infinity,
                        child: Row(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, color: gg),

                                SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextStyle(
                                      text: l10n.labelMyOrders,
                                      fontsize: 12,
                                      textColor: Theme.of(context).colorScheme.onSurface,
                                      bold: true,
                                    ),
                                    const SizedBox(height: 4),
                                    CustomTextStyle(
                                      bold: true,
                                      fontsize: 10,
                                      textColor: Colors.grey,
                                      text: l10n.msgManageAndTrack,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    //wishlist
                    BlocBuilder<WishlistCubit, WishlistState>(
                      builder: (context, state) {
                        int count = 0;
                        if (state is WishlistLoaded) {
                          count = state.items.length;
                        }
                        return Expanded(
                          child: CustomProContainer(
                            topLeftRadius: 12,
                            topRightRadius: 12,
                            bottomLeftRadius: 12,
                            bottomRightRadius: 12,
                            onTap: () {
                              context.push('/wishlist');
                            },
                            width: double.infinity,
                            child: Row(
                              children: [
                                Icon(Icons.favorite_border, color: gg),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomTextStyle(
                                      text: l10n.labelMyWishlist,
                                      fontsize: 12,
                                      textColor: Theme.of(context).colorScheme.onSurface,
                                      bold: true,
                                    ),
                                    const SizedBox(height: 4),
                                    CustomTextStyle(
                                      bold: true,
                                      fontsize: 10,
                                      textColor: Colors.grey,
                                      text: l10n.msgSavedItems(count),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () => context.push('/my-restock-requests'),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelAvailabilityRequests,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgTrackCancelRequests,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () => context.push('/category/viewed-before'),
                  child: Row(
                    children: [
                      Icon(Icons.history_toggle_off, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelViewedBefore,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgViewedBefore,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextStyle(
                  bold: true,
                  fontsize: 16,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  text: l10n.labelMyAccount,
                ),

                const SizedBox(height: 12),
                //address
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () async {
                    await context.push('/address');
                  },
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelAddress,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgManageAddresses,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                //payment methods
                const SizedBox(height: 12),
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () => context.push('/payment-methods'),
                  child: Row(
                    children: [
                      Icon(Icons.payment_outlined, color: gg),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextStyle(
                              text: l10n.labelPaymentMethods,
                              fontsize: 12,
                              textColor: Theme.of(context).colorScheme.onSurface,
                              bold: true,
                            ),
                            const SizedBox(height: 4),
                            CustomTextStyle(
                              bold: true,
                              fontsize: 10,
                              textColor: Colors.grey,
                              text: l10n.msgManagePaymentOptions,
                              maxLines: 1,
                              textOverflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                CustomTextStyle(
                  bold: true,
                  fontsize: 16,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  text: l10n.labelSettingsTitle,
                ),
                const SizedBox(height: 12),
                //language
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () => context.push('/language'),
                  child: Row(
                    children: [
                      Icon(Icons.language_outlined, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.language,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgSelectLanguage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                //security
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () => context.push('/security'),
                  child: Row(
                    children: [
                      Icon(Icons.security_outlined, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelSecurity,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgChangePasswordAndMore,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                //sign out
                CustomProContainer(
                  topLeftRadius: 12,
                  topRightRadius: 12,
                  bottomLeftRadius: 12,
                  bottomRightRadius: 12,
                  onTap: () {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                    // AppRouter should handle navigation based on auth status change.
                  },
                  child: Row(
                    children: [
                      Icon(Icons.logout_outlined, color: gg),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomTextStyle(
                            text: l10n.labelSignOut,
                            fontsize: 12,
                            textColor: Theme.of(context).colorScheme.onSurface,
                            bold: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextStyle(
                            bold: true,
                            fontsize: 10,
                            textColor: Colors.grey,
                            text: l10n.msgLogoutFromAccount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomProContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double topLeftRadius;
  final double topRightRadius;
  final double bottomLeftRadius;
  final double bottomRightRadius;
  final Function()? onTap;
  const CustomProContainer({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.topLeftRadius = 0,
    this.topRightRadius = 0,
    this.bottomLeftRadius = 0,
    this.bottomRightRadius = 0,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topLeftRadius),
      topRight: Radius.circular(topRightRadius),
      bottomLeft: Radius.circular(bottomLeftRadius),
      bottomRight: Radius.circular(bottomRightRadius),
    );
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: width,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MainProfile extends StatelessWidget {
  const MainProfile({
    super.key,
    required this.backgroundColor,
    required this.helloText,
    required this.username,
    required this.email,
  });

  final Color backgroundColor;
  final String helloText;
  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: backgroundColor,
              child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextStyle(
                  bold: true,
                  fontsize: 16,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  text: '$helloText $username',
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                CustomTextStyle(
                  text: email,
                  fontsize: 12,
                  textColor: Colors.grey,
                  bold: false,
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            final userState = context.read<UserCubit>().state;
            UserModel? currentUser;
            if (userState is UserLoaded) {
              currentUser = userState.user;
            } else if (userState is UserUpdateSuccess) {
              currentUser = userState.user;
            }
            context.push('/edit-profile', extra: currentUser);
          },
          icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
      ],
    );
  }
}
