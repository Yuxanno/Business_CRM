import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/app_tr.dart';
import 'components/app_splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/order_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/dashboard_provider.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait without blocking runApp()
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router(initialLocation: '/splash-wait');
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
      builder: (context, child) => AppStartupSplash(
        router: _router,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
