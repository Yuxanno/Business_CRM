import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/app_tr.dart';
import 'models/transaction.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/order_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/dashboard_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // Dev only: flutter run --dart-define=SEED_CATEGORIES=true
  if (const bool.fromEnvironment('SEED_CATEGORIES')) {
    const income = [
      'Продажа товаров', 'Услуги', 'Консультации', 'Подписки', 'Аренда (доход)',
      'Комиссии', 'Реклама (доход)', 'Обучение', 'Проекты', 'Поддержка',
      'Лицензии', 'Партнёрка', 'Возвраты', 'Гранты', 'Прочий доход',
    ];
    const expense = [
      'Закупка товаров', 'Аренда офиса', 'Зарплаты', 'Налоги', 'Реклама',
      'Транспорт', 'Связь и интернет', 'Коммунальные', 'Оборудование', 'Софт и сервисы',
      'Обучение персонала', 'Питание', 'Ремонт', 'Банковские комиссии', 'Прочие расходы',
    ];
    for (final c in income) {
      await settingsProvider.addCategory(TransactionType.income, c);
    }
    for (final c in expense) {
      await settingsProvider.addCategory(TransactionType.expense, c);
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
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
    final settings = context.read<SettingsProvider>();
    _router = AppRouter.router(settings.isOnboardingDone);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    AppTr.isEn = settings.locale == 'en';

    final locale = settings.locale == 'en'
        ? const Locale('en')
        : const Locale('ru');

    return MaterialApp.router(
      title: 'Business Manager',
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
