import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfume_app/core/localization/locale_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/core/router/go_router_refresh_stream.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:perfume_app/features/auth/presentation/cubit/registration_cubit.dart';
import 'package:perfume_app/features/cart/presentation/pages/cart_page.dart';
import 'package:perfume_app/features/home/presentation/pages/home_page.dart';
import 'package:perfume_app/features/auth/presentation/pages/login_page.dart';
import 'package:perfume_app/features/auth/presentation/pages/registration_page.dart';
import 'package:perfume_app/features/products/presentation/pages/category_products_page.dart';
import 'package:perfume_app/features/auth/presentation/pages/welcome_page.dart';
import 'package:perfume_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:perfume_app/features/auth/presentation/cubit/update_password_cubit.dart';
import 'package:perfume_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:perfume_app/features/home/presentation/manager/home_cubit.dart';
import 'package:perfume_app/features/home/presentation/pages/main_layout_page.dart';
import 'package:perfume_app/features/categories/presentation/pages/categories_page.dart';
import 'package:perfume_app/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:perfume_app/features/orders/presentation/pages/location_picker_page.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/home/data/repositories/banner_repository.dart';
import 'package:perfume_app/features/products/presentation/pages/product_details_page.dart';
import 'package:perfume_app/features/products/presentation/manager/product_details_cubit.dart';
import 'package:perfume_app/features/products/presentation/pages/search_page.dart';
import 'package:perfume_app/features/products/presentation/pages/search_results_page.dart';
import 'package:perfume_app/features/products/presentation/manager/recently_viewed_cubit.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/ai_chat/core/ai_chat_language.dart';
import 'package:perfume_app/features/ai_chat/data/repos/ai_chat_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_cubit.dart';
import 'package:perfume_app/features/categories/data/repos/category_repo.dart';

import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/orders/presentation/manager/orders_cubit.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/features/orders/presentation/pages/my_orders_page.dart';
import 'package:perfume_app/features/orders/presentation/pages/address_page.dart';
import 'package:perfume_app/features/orders/presentation/pages/checkout_page.dart';
import 'package:perfume_app/features/orders/presentation/manager/order_cubit.dart';
import 'package:perfume_app/features/profile/presentation/pages/profile_page.dart';
import 'package:perfume_app/features/profile/data/models/user_model.dart';
import 'package:perfume_app/features/profile/presentation/pages/payment_methods_page.dart';
import 'package:perfume_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:perfume_app/features/profile/presentation/pages/language_page.dart';
import 'package:perfume_app/features/profile/presentation/pages/security_page.dart';
import 'package:perfume_app/features/profile/presentation/pages/change_password_page.dart';
import 'package:perfume_app/features/profile/presentation/pages/my_restock_requests_page.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/wishlist/presentation/pages/wishlist_page.dart';
import 'package:perfume_app/features/orders/presentation/pages/order_success_page.dart';

String? resolveAuthRedirectForLocation({
  required AuthStatus authStatus,
  required String matchedLocation,
  String? requestedUri,
}) {
  const authRoutes = {'/', '/login', '/register', '/forgot-password'};
  const publicBrowseRoutes = {
    '/home',
    '/categories',
    '/ai-chat',
    '/MainLayout',
    '/product/:id',
    '/search',
    '/search-results',
    '/category/:name',
    '/cart',
    '/order-success',
  };
  final requestedPath = Uri.tryParse(requestedUri ?? '')?.path;
  final isAuthRoute = authRoutes.contains(matchedLocation);
  final isPublicBrowseRoute =
      publicBrowseRoutes.contains(matchedLocation) ||
      _isPublicBrowsePath(matchedLocation) ||
      (requestedPath != null && _isPublicBrowsePath(requestedPath));
  final isPublicRoute = isAuthRoute || isPublicBrowseRoute;

  if (authStatus == AuthStatus.unknown) return null;

  if (authStatus == AuthStatus.authenticated) {
    if (isAuthRoute) return '/MainLayout';
  } else {
    if (!isPublicRoute) {
      final returnTo = requestedUri?.trim();
      if (returnTo == null || returnTo.isEmpty) return '/login';
      final encodedReturnTo = Uri.encodeComponent(returnTo);
      final encodedBackTo = Uri.encodeComponent('/MainLayout');
      return '/login?returnTo=$encodedReturnTo&backTo=$encodedBackTo';
    }
  }

  return null;
}

bool _isPublicBrowsePath(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) return false;
  if (normalizedPath.startsWith('/product/')) return true;
  if (normalizedPath.startsWith('/category/')) return true;
  return false;
}

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      return resolveAuthRedirectForLocation(
        authStatus: authState.status,
        matchedLocation: state.matchedLocation,
        requestedUri: state.uri.toString(),
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => WelcomePage()),

      GoRoute(
        path: '/login',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          final backTo = state.uri.queryParameters['backTo'];
          final tabIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '');
          return BlocProvider(
            create: (context) =>
                LoginCubit(authRepository: context.read<AuthRepository>()),
            child: LoginPage(
              returnTo: returnTo,
              backTo: backTo,
              tabIndex: tabIndex,
            ),
          );
        },
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          final backTo = state.uri.queryParameters['backTo'];
          final tabIndex = int.tryParse(state.uri.queryParameters['tab'] ?? '');
          return BlocProvider(
            create: (context) => RegistrationCubit(
              authRepository: context.read<AuthRepository>(),
            ),
            child: RegistrationPage(
              returnTo: returnTo,
              backTo: backTo,
              tabIndex: tabIndex,
            ),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => BlocProvider(
          create: (context) => ForgotPasswordCubit(
            authRepository: context.read<AuthRepository>(),
          ),
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/MainLayout',
        redirect: (context, state) => '/home',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => HomeCubit(
                  context.read<ProductRepo>(),
                  context.read<BannerRepo>(),
                  context.read<CategoryRepo>(),
                )..fetchProducts(),
              ),
              BlocProvider(
                create: (context) => AIChatCubit(
                  aiChatRepo: AIChatRepo(
                    productRepo: context.read<ProductRepo>(),
                  ),
                  userTasteRepo: context.read<UserTasteRepo>(),
                  initialLanguage:
                      context.read<LocaleCubit>().state.languageCode == 'en'
                      ? AIChatLanguage.english
                      : AIChatLanguage.arabic,
                ),
              ),
            ],
            child: BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) =>
                  previous.user?.uid != current.user?.uid,
              listener: (context, state) {
                context.read<AIChatCubit>().handleAuthUserChanged(
                  state.user?.uid,
                );
              },
              child: MainLayout(navigationShell: navigationShell),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-chat',
                builder: (context, state) => const AIChatPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final productId = state.pathParameters['id']!;
          return BlocProvider(
            create: (context) =>
                ProductDetailsCubit(
                  context.read<ProductRepo>(),
                  context.read<EventRepo>(),
                  context.read<RecentlyViewedRepo>(),
                  context.read<UserTasteRepo>(),
                )..watchProduct(
                  productId,
                  onViewAdded: () async {
                    context.read<RecentlyViewedCubit>().refresh();
                  },
                ),
            child: ProductDetailsPage(
              productId: productId,
              source: state.uri.queryParameters['source'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final initialQuery = state.uri.queryParameters['initialQuery'];
          return SearchPage(initialQuery: initialQuery);
        },
      ),
      GoRoute(
        path: '/search-results',
        builder: (context, state) {
          final query = state.uri.queryParameters['query'] ?? '';
          return SearchResultsPage(query: query);
        },
      ),
      GoRoute(
        path: '/category/:name',
        builder: (context, state) {
          final categoryName = state.pathParameters['name']!;
          final categoryFilter =
              state.uri.queryParameters['filter'] ?? categoryName;
          final fragranceFamily = state.uri.queryParameters['family'];
          return CategoryProductsPage(
            categoryName: categoryName,
            categoryFilter: categoryFilter,
            fragranceFamily: fragranceFamily,
          );
        },
      ),
      // /cart and /profile removed because they are in the StatefulShellRoute
      GoRoute(
        path: '/my-orders',
        builder: (context, state) => BlocProvider(
          create: (context) => OrdersCubit(
            orderRepo: context.read<OrderRepo>(),
            authBloc: context.read<AuthBloc>(),
          )..loadOrders(),
          child: const MyOrdersPage(),
        ),
      ),
      GoRoute(
        path: '/address',
        builder: (context, state) => const AddressPage(showPickupTab: false),
      ),
      GoRoute(
        path: '/add-address-entry',
        builder: (context, state) => const AddressPageInfoEntry(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => BlocProvider(
          create: (context) => OrderCubit(
            orderRepo: context.read<OrderRepo>(),
            eventRepo: context.read<EventRepo>(),
            userTasteRepo: context.read<UserTasteRepo>(),
          ),
          child: const CheckoutPage(),
        ),
      ),
      GoRoute(
        path: '/location-picker',
        builder: (context, state) => const LocationPickerPage(),
      ),
      GoRoute(
        path: '/saved-addresses',
        builder: (context, state) => const SavedAddress(),
      ),
      // Profile moved to StatefulShellRoute
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) =>
            EditProfilePage(user: state.extra as UserModel?),
      ),
      GoRoute(
        path: '/payment-methods',
        builder: (context, state) => const PaymentMethodsPage(),
      ),
      GoRoute(
        path: '/my-restock-requests',
        builder: (context, state) => const MyRestockRequestsPage(),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => BlocProvider(
          create: (context) => UpdatePasswordCubit(
            authRepository: context.read<AuthRepository>(),
          ),
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistPage(),
      ),
      // PPF.T02 — top-level success route, NOT nested under /checkout or /cart
      GoRoute(
        path: '/order-success',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] ?? '';
          final orderCode = state.uri.queryParameters['orderCode'];
          final cartCleanupFailed =
              state.uri.queryParameters['cartCleanupFailed'] == 'true';
          return OrderSuccessPage(
            orderId: orderId,
            orderCode: orderCode,
            cartCleanupFailed: cartCleanupFailed,
          );
        },
      ),
    ],
  );
}
