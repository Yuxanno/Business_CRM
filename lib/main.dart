import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'components/auth/auth_header.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_tr.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/order_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/dashboard_provider.dart';
import 'router/app_router.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/brand_splash.dart';
import 'services/performance_service.dart';
import 'services/api_client.dart';
import 'services/sync_queue.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceService.instance.startMonitoring();

  // Disable runtime network font fetching so first frame never stalls on font HTTP requests.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Lock to portrait without blocking startup.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const BusinessManagerApp(),
    ),
  );
}

class BusinessManagerApp extends StatefulWidget {
  const BusinessManagerApp({super.key});

  /// Notifies screens when the cold-start BrandSplash has finished so dialogs
  /// and background reminders never collide with the splash transition.
  static final ValueNotifier<bool> splashCompleted = ValueNotifier<bool>(false);

  @override
  State<BusinessManagerApp> createState() => _BusinessManagerAppState();
}

class _BusinessManagerAppState extends State<BusinessManagerApp> {
  static bool _coldStartSplashShown = false;

  bool _ready = false;
  bool _splashDone = _coldStartSplashShown;
  final ValueNotifier<SplashTarget?> _splashTarget =
      ValueNotifier<SplashTarget?>(null);
  final GlobalKey _routerAppKey = GlobalKey(debugLabel: 'bizflow_router_app');
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    BusinessManagerApp.splashCompleted.value = _coldStartSplashShown;
    _initStartup();
  }

  Future<void> _initStartup() async {
    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();
    final customers = context.read<CustomerProvider>();
    final orders = context.read<OrderProvider>();
    final finance = context.read<FinanceProvider>();
    final debts = context.read<DebtProvider>();

    try {
      await settings
          .init(skipRemoteSync: true)
          .timeout(const Duration(milliseconds: 1800));
    } catch (_) {}
    if (!mounted) return;

    // Pre-hydrate local snapshot cache before creating GoRouter so the initial
    // screen (/home or /login) renders its first frame with data already in memory.
    try {
      await Future.wait([
        dashboard.hydrateFromCache(),
        customers.hydrateFromCache(),
        orders.hydrateFromCache(),
        finance.hydrateFromCache(),
        debts.hydrateFromCache(),
      ]).timeout(const Duration(milliseconds: 600));
    } catch (_) {}
    if (!mounted) return;

    final isDone = settings.isOnboardingDone;
    _router = AppRouter.router(
      initialLocation: isDone ? '/home' : '/login',
    );
    _splashTarget.value = isDone ? SplashTarget.home : SplashTarget.login;
    setState(() => _ready = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiClient.instance.warmUp();
    });
  }

  void _onSplashFinished() {
    _coldStartSplashShown = true;
    BusinessManagerApp.splashCompleted.value = true;
    if (!mounted || _splashDone) return;
    setState(() => _splashDone = true);
  }

  @override
  void dispose() {
    _splashTarget.dispose();
    if (_ready) {
      _router?.dispose();
    }
    super.dispose();
  }

  Widget _buildRouterApp(BuildContext context) {
    final localeCode =
        context.select<SettingsProvider, String>((s) => s.locale);
    AppTr.isEn = localeCode == 'en';

    final locale = localeCode == 'en'
        ? const Locale('en')
        : const Locale('ru');

    return MaterialApp.router(
      key: _routerAppKey,
      title: 'BizFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appReady = _ready && _router != null;

    // Keep the outer Directionality -> Stack permanently so MaterialApp.router
    // and GoRouter's StatefulShellRoute are NEVER unmounted or re-parented
    // when _splashDone transitions from false to true.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (appReady) _buildRouterApp(context),
          if (!_splashDone)
            BrandSplash(
              key: const ValueKey('cold_start_brand_splash'),
              target: _splashTarget,
              onFinished: _onSplashFinished,
              loginLogoKey: AuthHeader.logoKey,
              loginWordKey: AuthHeader.wordKey,
              homeAvatarKey: HomeScreen.avatarKey,
            ),
        ],
      ),
    );
  }
}
