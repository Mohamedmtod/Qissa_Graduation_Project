// navigation Callback

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';

VoidCallback navigateToWelcome(BuildContext context) {
  return () {
    context.go('/');
  };
}

VoidCallback navigateToLogin(BuildContext context) {
  return () {
    context.go('/login');
  };
}

void goToLoginForProtectedTab(BuildContext context, int tabIndex) {
  final encodedReturnTo = Uri.encodeComponent('/MainLayout');
  final encodedBackTo = Uri.encodeComponent('/MainLayout');
  context.go(
    '/login?returnTo=$encodedReturnTo&backTo=$encodedBackTo&tab=$tabIndex',
  );
}

VoidCallback navigateToLoginForCheckout(BuildContext context) {
  return () {
    final encodedReturnTo = Uri.encodeComponent('/checkout');
    final encodedBackTo = Uri.encodeComponent('/MainLayout');
    context.go(
      '/login?returnTo=$encodedReturnTo&backTo=$encodedBackTo&tab=${Go.cart}',
    );
  };
}

VoidCallback navigateToRegistration(BuildContext context) {
  return () {
    context.go('/register');
  };
}

VoidCallback navigateToRegistrationWithReturn(
  BuildContext context, {
  String? returnTo,
  String? backTo,
  int? tabIndex,
}) {
  return () {
    context.go(
      registrationPathWithReturn(
        returnTo: returnTo,
        backTo: backTo,
        tabIndex: tabIndex,
      ),
    );
  };
}

String registrationPathWithReturn({
  String? returnTo,
  String? backTo,
  int? tabIndex,
}) {
  final params = <String, String>{
    if (returnTo != null && returnTo.trim().isNotEmpty)
      'returnTo': returnTo.trim(),
    if (backTo != null && backTo.trim().isNotEmpty) 'backTo': backTo.trim(),
    if (tabIndex != null) 'tab': '$tabIndex',
  };
  return Uri(
    path: '/register',
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

VoidCallback navigateToHome(BuildContext context) {
  return () {
    context.go('/home');
  };
}

VoidCallback navigateToGuestBrowsing(BuildContext context) {
  return () {
    context.read<LayoutCubit>().changeIndex(Go.home);
    context.go('/MainLayout');
  };
}

VoidCallback logoutNavigateToHome(BuildContext context) {
  return () {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  };
}

VoidCallback navigateToForgotPassword(BuildContext context) {
  return () {
    context.push('/forgot-password');
  };
}

VoidCallback navigateToProductDetails(BuildContext context, String productId) {
  return () {
    context.go('/product/$productId');
  };
}

VoidCallback navigateToSearch(BuildContext context) {
  return () {
    context.go('/search');
  };
}

VoidCallback navigateToSearchResults(BuildContext context, String query) {
  return () {
    context.go('/search-results?query=$query');
  };
}

VoidCallback navigateToCheckout(BuildContext context) {
  return () {
    context.go('/checkout');
  };
}

VoidCallback navigateToOrders(BuildContext context) {
  return () {
    context.push('/my-orders');
  };
}

VoidCallback navigateToAddress(BuildContext context) {
  return () {
    context.go('/address');
  };
}

VoidCallback navigateToLocationPicker(BuildContext context) {
  return () {
    context.push('/location-picker');
  };
}

VoidCallback navigateToSavedAddresses(BuildContext context) {
  return () {
    context.go('/saved-addresses');
  };
}

class Go {
  static const int home = 0;
  static const int categories = 1;
  static const int aiChat = 2;
  static const int cart = 3;
  static const int profile = 4;
}

VoidCallback navigateToMainLayout(BuildContext context, [int index = Go.home]) {
  return () {
    context.read<LayoutCubit>().changeIndex(index);
    context.go('/MainLayout');
  };
}

VoidCallback navigateToCart(BuildContext context, [int index = Go.cart]) {
  return () {
    context.read<LayoutCubit>().changeIndex(Go.cart);
    context.go('/MainLayout');
  };
}

VoidCallback navigateToProfile(BuildContext context, [int index = Go.profile]) {
  return () {
    context.read<LayoutCubit>().changeIndex(Go.profile);
    context.go('/MainLayout');
  };
}
