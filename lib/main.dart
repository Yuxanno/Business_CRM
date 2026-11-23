import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable runtime network font fetching so first frame never stalls on font HTTP requests.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Lock to portrait without blocking startup.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));

  final settingsProvider = SettingsProvider();
  final dashboardProvider = DashboardProvider();

  // Fast local preload capped at 150ms so startup is never blocked.
  try {
    await Future.wait([
      settingsProvider.init(skipRemoteSync: true),
      dashboardProvider.hydrateFromCache(),
    ]).timeout(const Duration(milliseconds: 150));
  } catch (_) {}

  final initialLocation =
      settingsProvider.isOnboardingDone ? '/home' : '/login';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider.value(value: dashboardProvider),
      ],
      child: BusinessManagerApp(initialLocation: initialLocation),
    ),
  );
}

class BusinessManagerApp extends StatefulWidget {
  const BusinessManagerApp({
    super.key,
    required this.initialLocation,
  });

  final String initialLocation;

  @override
  State<BusinessManagerApp> createState() => _BusinessManagerAppState();
}

class _BusinessManagerAppState extends State<BusinessManagerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router(initialLocation: widget.initialLocation);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode =
        context.select<SettingsProvider, String>((s) => s.locale);
    AppTr.isEn = localeCode == 'en';

    final locale = localeCode == 'en'
        ? const Locale('en')
        : const Locale('ru');

    return MaterialApp.router(
      title: 'BizFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
