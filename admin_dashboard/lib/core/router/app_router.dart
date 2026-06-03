import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_auth_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/access_error_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/admin_shell.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/ai_insights_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/content_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/dashboard_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/finance_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/inventory_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/login_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/orders_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/unauthorized_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/delivery_zones_page.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/pages/users_page.dart';
import 'package:perfume_app_admin_dashboard/features/pos/data/repos/pos_repository.dart';
import 'package:perfume_app_admin_dashboard/features/pos/presentation/cubit/pos_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/pos/presentation/cubit/cash_session_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/pos/presentation/screens/pos_screen.dart';
import 'package:perfume_app_admin_dashboard/features/pos/presentation/pages/recipe_management_page.dart';

class AppRouter {
  static const String login = '/login';
  static const String unauthorized = '/unauthorized';
  static const String accessError = '/access-error';
  static const String dashboard = '/dashboard';
  static const String orders = '/orders';
  static const String inventory = '/inventory';
  static const String content = '/content';
  static const String users = '/users';
  static const String finance = '/finance';
  static const String aiInsights = '/ai-insights';
  static const String deliveryZones = '/delivery-zones';
  static const String pos = '/pos';
  static const String recipes = '/recipes';

  static GoRouter createRouter(AdminAuthRepository authRepository) {
    return GoRouter(
      initialLocation: dashboard,
      refreshListenable: authRepository,
      redirect: (context, state) async {
        final location = state.uri.path;
        final isLoggingIn = location == login;
        final isUnauthorized = location == unauthorized;
        final isAccessError = location == accessError;

        final access = await authRepository.resolveAccess();

        switch (access.status) {
          case AdminAccessStatus.unauthenticated:
            return isLoggingIn ? null : login;
          case AdminAccessStatus.unauthorized:
            return isUnauthorized ? null : unauthorized;
          case AdminAccessStatus.recoverableFailure:
            return isAccessError ? null : accessError;
          case AdminAccessStatus.authorized:
            if (isLoggingIn ||
                isUnauthorized ||
                isAccessError ||
                location == '/') {
              return dashboard;
            }
            return null;
        }
      },
      routes: [
        GoRoute(path: '/', redirect: (context, state) => dashboard),
        GoRoute(path: login, builder: (context, state) => const LoginPage()),
        GoRoute(
          path: unauthorized,
          builder: (context, state) => const UnauthorizedPage(),
        ),
        GoRoute(
          path: accessError,
          builder: (context, state) => const AccessErrorPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: dashboard,
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              path: orders,
              builder: (context, state) => const OrdersPage(),
            ),
            GoRoute(
              path: inventory,
              builder: (context, state) => const InventoryPage(),
            ),
            GoRoute(
              path: content,
              builder: (context, state) => const ContentPage(),
            ),
            GoRoute(
              path: users,
              builder: (context, state) => const UsersPage(),
            ),
            GoRoute(
              path: finance,
              builder: (context, state) => const FinancePage(),
            ),
            GoRoute(
              path: aiInsights,
              builder: (context, state) => const AiInsightsPage(),
            ),
            GoRoute(
              path: deliveryZones,
              builder: (context, state) => const DeliveryZonesPage(),
            ),
            GoRoute(
              path: pos,
              builder: (context, state) {
                final posRepository = RepositoryProvider.of<PosRepository>(context);
                return MultiBlocProvider(
                  providers: [
                    BlocProvider<CashSessionCubit>(
                      create: (context) => CashSessionCubit(posRepository),
                    ),
                    BlocProvider<PosCubit>(
                      create: (context) => PosCubit(posRepository),
                    ),
                  ],
                  child: const PosScreen(),
                );
              },
            ),
            GoRoute(
              path: recipes,
              builder: (context, state) => const RecipeManagementPage(),
            ),
          ],
        ),
      ],
    );
  }
}
