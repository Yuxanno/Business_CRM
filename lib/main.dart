import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/app_tr.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/order_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/dashboard_provider.dart';
import 'router/app_router.dart';
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

  @override
  State<BusinessManagerApp> createState() => _BusinessManagerAppState();
}

class _BusinessManagerAppState extends State<BusinessManagerApp> {
  bool _ready = false;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _initStartup();
  }

  Future<void> _initStartup() async {
    final settings = context.read<SettingsProvider>();
    final dashboard = context.read<DashboardProvider>();
    final customers = context.read<CustomerProvider>();
    final orders = context.read<OrderProvider>();
    final finance = context.read<FinanceProvider>();
    final debts = context.read<DebtProvider>();

    await settings.init(skipRemoteSync: true);
    if (!mounted) return;

    _router = AppRouter.router(
      initialLocation: settings.isOnboardingDone ? '/home' : '/login',
    );
    setState(() => _ready = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future.wait([
        dashboard.hydrateFromCache(),
        customers.hydrateFromCache(),
        orders.hydrateFromCache(),
        finance.hydrateFromCache(),
        debts.hydrateFromCache(),
      ]));
      ApiClient.instance.warmUp();
    });
  }

  @override
  void dispose() {
    if (_ready) {
      _router?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _router == null) {
      return const ColoredBox(color: AppColors.lightBackground);
    }

    final localeCode =
        context.select<SettingsProvider, String>((s) => s.locale);
    AppTr.isEn = localeCode == 'en';

    final locale = localeCode == 'en'
        ? const Locale('en')
        : const Locale('ru');

    return MaterialApp.router(
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
}
