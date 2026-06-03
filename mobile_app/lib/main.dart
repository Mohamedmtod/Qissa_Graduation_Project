import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/core/router/app_router.dart';
import 'package:perfume_app/features/auth/data/auth_repository.dart';
import 'package:perfume_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:perfume_app/features/orders/data/repos/address_repo.dart';
import 'package:perfume_app/features/orders/data/repos/shipping_zones_repo.dart';
import 'package:perfume_app/features/orders/presentation/cubit/shipping/shipping_zones_cubit.dart';
import 'package:perfume_app/features/products/data/local/recently_viewed_local_data_source.dart';
import 'package:perfume_app/features/products/data/models/product_model.dart';
import 'package:perfume_app/features/products/data/repos/frequent_recommendation_repo.dart';
import 'package:perfume_app/features/products/data/repos/product_repo.dart';
import 'package:perfume_app/features/products/data/repos/recently_viewed_repo.dart';
import 'package:perfume_app/features/home/data/repositories/banner_repository.dart';
import 'package:perfume_app/features/cart/presentation/manager/cart_cubit.dart';
import 'package:perfume_app/features/cart/data/repos/cart_repo.dart';
import 'package:perfume_app/features/wishlist/data/repos/wishlist_repo.dart';
import 'package:perfume_app/features/wishlist/presentation/manager/wishlist_cubit.dart';
import 'package:perfume_app/features/events/data/repos/event_repo.dart';
import 'package:perfume_app/features/categories/data/repos/category_repo.dart';
import 'package:perfume_app/features/orders/data/repos/order_repo.dart';
import 'package:perfume_app/firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:perfume_app/features/home/presentation/manager/layout_cubit.dart';
import 'package:perfume_app/features/orders/presentation/cubit/address/address_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/recently_viewed_cubit.dart';
import 'package:perfume_app/features/products/presentation/manager/search_cubit.dart';
import 'package:perfume_app/l10n/app_localizations.dart';
import 'package:perfume_app/core/localization/locale_repository.dart';
import 'package:perfume_app/core/localization/locale_cubit.dart';
import 'package:perfume_app/features/profile/data/repos/user_repo.dart';
import 'package:perfume_app/features/profile/presentation/manager/user_cubit.dart';
import 'package:perfume_app/features/recommendations/data/local/user_taste_local_data_source.dart';
import 'package:perfume_app/features/recommendations/data/repos/user_taste_repo.dart';
import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_experiment_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _configureDebugAIChatFlags();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final localeRepo = LocaleRepository();
  final savedLocale = await localeRepo.getSavedLocale();

  final initialLocale = savedLocale ?? _resolveDeviceLocale();

  runApp(MyApp(initialLocale: initialLocale, localeRepo: localeRepo));
}

void _configureDebugAIChatFlags() {
  if (kReleaseMode) return;
  AIChatExperimentConfig.setTestOverrides(
    sendCompactContext: true,
    useCatalogSearchEngine: true,
    useSuitabilityPolicy: true,
    toolRouterV1: false,
  );
}

Locale _resolveDeviceLocale() {
  final deviceLocale = PlatformDispatcher.instance.locale;
  if (deviceLocale.languageCode == 'ar') {
    return const Locale('ar');
  }
  return const Locale('en');
}

class MyApp extends StatelessWidget {
  final Locale initialLocale;
  final LocaleRepository localeRepo;

  const MyApp({
    required this.initialLocale,
    required this.localeRepo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(
          create: (context) {
            final repo = ProductRepo();
            unawaited(
              repo.warmUpCatalog().catchError((
                Object error,
                StackTrace stackTrace,
              ) {
                log(
                  'Catalog warm-up failed.',
                  name: 'ProductRepo',
                  error: error,
                  stackTrace: stackTrace,
                );
                return const <ProductModel>[];
              }),
            );
            return repo;
          },
        ),
        RepositoryProvider(
          create: (context) => RecentlyViewedRepo(
            localDataSource: SharedPreferencesRecentlyViewedLocalDataSource(),
            productRepo: context.read<ProductRepo>(),
          ),
        ),
        RepositoryProvider(create: (context) => FrequentRecommendationRepo()),
        RepositoryProvider(create: (context) => BannerRepo()),
        RepositoryProvider(create: (context) => CartRepo()),
        RepositoryProvider(create: (context) => EventRepo()),
        RepositoryProvider(create: (context) => OrderRepo()),
        RepositoryProvider(create: (context) => AddressRepo()),
        RepositoryProvider(create: (context) => WishlistRepo()),
        RepositoryProvider(create: (context) => CategoryRepo()),
        RepositoryProvider(create: (context) => UserRepo()),
        RepositoryProvider(
          create: (context) => UserTasteRepo(
            localDataSource: SharedPreferencesUserTasteLocalDataSource(),
          ),
        ),
        RepositoryProvider(create: (context) => localeRepo),
        RepositoryProvider(create: (context) => ShippingZonesRepo()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>())
                  ..add(AppStarted()),
          ),
          BlocProvider(create: (context) => LayoutCubit()),
          BlocProvider(create: (context) => AddressCubit()..loadAddresses()),
          BlocProvider(
            create: (context) => CartCubit(
              cartRepo: context.read<CartRepo>(),
              authBloc: context.read<AuthBloc>(),
              productRepo: context.read<ProductRepo>(),
            ),
          ),
          BlocProvider(
            create: (context) => WishlistCubit(
              wishlistRepo: context.read<WishlistRepo>(),
              authBloc: context.read<AuthBloc>(),
              productRepo: context.read<ProductRepo>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                RecentlyViewedCubit(context.read<RecentlyViewedRepo>())
                  ..loadRecentlyViewed(),
          ),
          BlocProvider(
            create: (context) => SearchCubit(
              context.read<ProductRepo>(),
              context.read<EventRepo>(),
              context.read<RecentlyViewedRepo>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                ShippingZonesCubit(context.read<ShippingZonesRepo>())
                  ..loadZones(),
          ),
          BlocProvider(
            create: (context) => LocaleCubit(
              context.read<LocaleRepository>(),
              initialLocale: initialLocale,
            ),
          ),
          BlocProvider(
            create: (context) => UserCubit(context.read<UserRepo>()),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(context.read<AuthBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        final userCubit = context.read<UserCubit>();

        if (state.status == AuthStatus.authenticated) {
          final uid = state.user?.uid;
          if (uid != null && uid.isNotEmpty) {
            userCubit.watchUser(uid);
          }
          return;
        }

        userCubit.clearUser();
      },
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            scrollBehavior: MyCustomScrollBehavior(),
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme,
            routerConfig: _router,
            builder: (context, child) {
              // Constrain the app to a max width of ~8-inch phone (430 dp)
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}
