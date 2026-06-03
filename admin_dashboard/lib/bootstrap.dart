import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perfume_app_admin_dashboard/core/config/app_config.dart';
import 'package:perfume_app_admin_dashboard/core/config/app_flavor.dart';
import 'package:perfume_app_admin_dashboard/core/localization/admin_locale_controller.dart';
import 'package:perfume_app_admin_dashboard/core/logging/admin_action_logger.dart';
import 'package:perfume_app_admin_dashboard/core/observability/admin_observability_service.dart';
import 'package:perfume_app_admin_dashboard/core/router/app_router.dart';
import 'package:perfume_app_admin_dashboard/core/theme/app_theme.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_ai_insights_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_analytics_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_auth_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_content_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_inventory_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_media_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_orders_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_shipping_zones_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/repos/admin_users_repository.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_ai_insights_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_firestore_analytics_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_firestore_inventory_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_firestore_orders_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_inventory_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_media_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_orders_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_content_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_security_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_shipping_zones_service.dart';
import 'package:perfume_app_admin_dashboard/features/admin/data/services/admin_users_worker_client.dart';
import 'package:perfume_app_admin_dashboard/features/admin/presentation/manager/admin_auth_cubit.dart';
import 'package:perfume_app_admin_dashboard/features/pos/data/datasources/pos_local_datasource.dart';
import 'package:perfume_app_admin_dashboard/features/pos/data/services/pos_remote_service.dart';
import 'package:perfume_app_admin_dashboard/features/pos/data/repos/pos_repository.dart';


Future<void> bootstrap(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.forFlavor(flavor);
  await initializeDateFormatting('ar_EG');
  await initializeDateFormatting('en_US');
  await Firebase.initializeApp(options: config.firebaseOptions);

  Locale? initialLocale;
  SharedPreferences? sharedPrefs;
  try {
    final prefs = await SharedPreferences.getInstance();
    sharedPrefs = prefs;
    final savedCode = prefs.getString('admin_language_code');
    if (savedCode != null && savedCode.trim().isNotEmpty) {
      initialLocale = Locale(savedCode.trim());
    }
  } catch (e) {
    debugPrint('[admin][bootstrap][locale_load_failed] error=$e');
  }

  runApp(AdminBootstrapApp(
    config: config,
    initialLocale: initialLocale,
    sharedPreferences: sharedPrefs,
  ));
}

class AdminBootstrapApp extends StatefulWidget {
  const AdminBootstrapApp({
    super.key,
    required this.config,
    this.initialLocale,
    this.sharedPreferences,
  });

  final AppConfig config;
  final Locale? initialLocale;
  final SharedPreferences? sharedPreferences;

  @override
  State<AdminBootstrapApp> createState() => _AdminBootstrapAppState();
}

class _AdminBootstrapAppState extends State<AdminBootstrapApp> {
  late final AdminAuthRepository _authRepository;
  late final AdminActionLogger _logger;
  late final AdminObservabilityService _observability;
  late final AdminSecurityService _securityService;
  late final AdminAnalyticsRepository _analyticsRepository;
  late final AdminOrdersRepository _ordersRepository;
  late final AdminInventoryRepository _inventoryRepository;
  late final AdminContentRepository _contentRepository;
  late final AdminMediaRepository _mediaRepository;
  late final AdminAiInsightsRepository _aiInsightsRepository;
  late final AdminShippingZonesRepository _shippingZonesRepository;
  late final AdminShippingZonesService _shippingZonesService;
  late final AdminUsersRepository _usersRepository;
  late final PosRepository _posRepository;
  late final AdminLocaleController _localeController;
  late final AdminAuthCubit _authCubit;
  late final GoRouter _router;

  bool _isHandlingFrameworkError = false;
  bool _isHandlingPlatformError = false;
  DateTime? _lastFrameworkErrorAt;
  DateTime? _lastPlatformErrorAt;
  String? _lastFrameworkErrorSignature;
  String? _lastPlatformErrorSignature;
  int _suppressedFrameworkErrors = 0;
  int _suppressedPlatformErrors = 0;

  @override
  void initState() {
    super.initState();
    _authRepository = AdminAuthRepository();
    _observability = AdminObservabilityService();
    _logger = AdminActionLogger(widget.config);
    _installErrorHooks();
    _securityService = AdminSecurityService(
      _authRepository,
      _logger,
      _observability,
    );
    _analyticsRepository = LocalAdminAnalyticsRepository(
      FirestoreAdminAnalyticsService(observability: _observability),
      securityService: _securityService,
      logger: _logger,
      observability: _observability,
    );
    _ordersRepository = FirestoreAdminOrdersRepository(
      FirestoreAdminOrdersService(),
      AdminOrdersWorkerClient(
        baseUrl: widget.config.ordersWorkerBaseUrl,
        workerApiKey: widget.config.workerApiKey,
        logger: _logger,
      ),
      _securityService,
      _logger,
      observability: _observability,
      ordersWorkerBaseUrl: widget.config.ordersWorkerBaseUrl,
      useWorkerTransitions: widget.config.useWorkerOrderTransitions,
    );
    _inventoryRepository = FirestoreAdminInventoryRepository(
      FirestoreAdminInventoryService(
        workerClient: AdminInventoryWorkerClient(
          baseUrl: widget.config.ordersWorkerBaseUrl,
          workerApiKey: widget.config.workerApiKey,
          logger: _logger,
        ),
      ),
      _securityService,
      _logger,
      observability: _observability,
    );
    _contentRepository = FirestoreAdminContentRepository(
      FirestoreAdminContentService(),
      _securityService,
      _logger,
      observability: _observability,
    );
    _mediaRepository = WorkerAdminMediaRepository(
      AdminMediaWorkerClient(
        baseUrl: widget.config.ordersWorkerBaseUrl,
        workerApiKey: widget.config.workerApiKey,
        logger: _logger,
      ),
      _securityService,
      _logger,
      observability: _observability,
    );
    _aiInsightsRepository = LocalAdminAiInsightsRepository(
      FirestoreAdminAiInsightsService(),
      securityService: _securityService,
      logger: _logger,
      observability: _observability,
    );
    _shippingZonesRepository = AdminShippingZonesRepository();
    _shippingZonesService = AdminShippingZonesService(
      _shippingZonesRepository,
      _securityService,
      _observability,
    );
    _usersRepository = FirestoreAdminUsersRepository(
      AdminUsersWorkerClient(
        baseUrl: widget.config.ordersWorkerBaseUrl,
        workerApiKey: widget.config.workerApiKey,
        logger: _logger,
      ),
      _securityService,
      _logger,
      observability: _observability,
    );

    final prefs = widget.sharedPreferences;
    final posLocalDatasource = PosLocalDatasource(prefs ?? widget.sharedPreferences!);
    final posRemoteService = PosRemoteService(
      ordersBaseUrl: widget.config.ordersWorkerBaseUrl,
    );
    _posRepository = PosRepositoryImpl(posRemoteService, posLocalDatasource);

    _logger.info(
      'Environment initialized.',
      context: {
        'flavor': widget.config.flavor.name,
        'ordersWorkerBaseUrl': widget.config.ordersWorkerBaseUrl,
        'aiChatWorkerBaseUrl': widget.config.aiChatWorkerBaseUrl,
        'workerApiKeyConfigured': widget.config.workerApiKey.isNotEmpty,
        'useWorkerOrderTransitions': widget.config.useWorkerOrderTransitions,
        'logLevel': widget.config.logLevel.name,
      },
    );
    _authCubit = AdminAuthCubit(_authRepository)..refreshAccess();
    _localeController = AdminLocaleController(initialLocale: widget.initialLocale);
    _router = AppRouter.createRouter(_authRepository);
  }

  @override
  void dispose() {
    _authCubit.close();
    _localeController.dispose();
    _authRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MultiProvider(
      providers: [
        ListenableProvider<AdminObservabilityService>.value(
          value: _observability,
        ),
        ChangeNotifierProvider<AdminLocaleController>.value(
          value: _localeController,
        ),
      ],
      child: Consumer<AdminLocaleController>(
        builder: (context, localeController, _) {
          if (!localeController.isReady) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          }

          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AdminActionLogger>.value(
                value: _logger,
              ),
              RepositoryProvider<AdminAnalyticsRepository>.value(
                value: _analyticsRepository,
              ),
              RepositoryProvider<AdminOrdersRepository>.value(
                value: _ordersRepository,
              ),
              RepositoryProvider<AdminInventoryRepository>.value(
                value: _inventoryRepository,
              ),
              RepositoryProvider<AdminContentRepository>.value(
                value: _contentRepository,
              ),
              RepositoryProvider<AdminMediaRepository>.value(
                value: _mediaRepository,
              ),
              RepositoryProvider<AdminAiInsightsRepository>.value(
                value: _aiInsightsRepository,
              ),
              RepositoryProvider<AdminShippingZonesService>.value(
                value: _shippingZonesService,
              ),
              RepositoryProvider<AdminUsersRepository>.value(
                value: _usersRepository,
              ),
              RepositoryProvider<PosRepository>.value(
                value: _posRepository,
              ),
            ],
            child: BlocProvider.value(
              value: _authCubit,
              child: MaterialApp.router(
                title: localeController.t(
                  'app.name',
                  fallback: widget.config.appName,
                ),
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                locale: localeController.locale,
                supportedLocales: AdminLocaleController.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                routerConfig: _router,
              ),
            ),
          );
        },
      ),
    );

    if (!widget.config.showFlavorBanner) {
      return app;
    }

    return Directionality(
      textDirection: _localeController.isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Banner(
        message: widget.config.flavor.displayName,
        location: BannerLocation.topStart,
        color: widget.config.flavor == AppFlavor.dev
            ? const Color(0xFF2E7D32)
            : const Color(0xFF8C4F10),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        child: app,
      ),
    );
  }

  void _installErrorHooks() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final signature =
          '${details.library ?? 'unknown'}|${details.exceptionAsString()}';
      final now = DateTime.now();
      final duplicateBurst =
          _lastFrameworkErrorSignature == signature &&
          _lastFrameworkErrorAt != null &&
          now.difference(_lastFrameworkErrorAt!).inMilliseconds < 1200;
      _lastFrameworkErrorSignature = signature;
      _lastFrameworkErrorAt = now;

      if (_isHandlingFrameworkError || duplicateBurst) {
        _suppressedFrameworkErrors += 1;
        previousOnError?.call(details);
        return;
      }

      _isHandlingFrameworkError = true;
      final traceId = _observability.createTraceId('flutter-error');
      _logger.error(
        'Flutter framework error captured.',
        context: {
          'traceId': traceId,
          'library': details.library ?? 'unknown',
          'exception': details.exceptionAsString(),
          'suppressedDuplicates': _suppressedFrameworkErrors,
        },
      );
      try {
        _observability.recordIssue(
          AdminProductionIssue(
            traceId: traceId,
            title: 'Flutter framework error',
            source: details.library ?? 'flutter',
            occurredAt: DateTime.now(),
            severity: AdminIssueSeverity.error,
            message: details.exceptionAsString(),
          ),
        );
      } finally {
        _suppressedFrameworkErrors = 0;
        _isHandlingFrameworkError = false;
        previousOnError?.call(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      final signature = '${error.runtimeType}|$error';
      final now = DateTime.now();
      final duplicateBurst =
          _lastPlatformErrorSignature == signature &&
          _lastPlatformErrorAt != null &&
          now.difference(_lastPlatformErrorAt!).inMilliseconds < 1200;
      _lastPlatformErrorSignature = signature;
      _lastPlatformErrorAt = now;

      if (_isHandlingPlatformError || duplicateBurst) {
        _suppressedPlatformErrors += 1;
        return false;
      }

      _isHandlingPlatformError = true;
      final traceId = _observability.createTraceId('platform-error');
      _logger.error(
        'Unhandled platform error captured.',
        context: {
          'traceId': traceId,
          'error': error.toString(),
          'suppressedDuplicates': _suppressedPlatformErrors,
        },
      );
      try {
        _observability.recordIssue(
          AdminProductionIssue(
            traceId: traceId,
            title: 'Unhandled platform error',
            source: 'platform_dispatcher',
            occurredAt: DateTime.now(),
            severity: AdminIssueSeverity.critical,
            message: error.toString(),
          ),
        );
      } finally {
        _suppressedPlatformErrors = 0;
        _isHandlingPlatformError = false;
      }
      return false;
    };
  }
}
