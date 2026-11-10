import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_avatar.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';
import '../../components/app_confirm_sheet.dart';
import 'account_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeOrdersCount = 0;
  int _receivableCents = 0;
  int _payableCents = 0;
  String _accountName = '';
  String _login = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settingsProvider = context.read<SettingsProvider>();
      final customerProvider = context.read<CustomerProvider>();
      final debtProvider = context.read<DebtProvider>();
      final orderProvider = context.read<OrderProvider>();

      final account = await AccountStore.load();
      if (!mounted) return;
      setState(() {
        _accountName = account.name;
        _login = account.login;
      });
      // Sync all server-provided settings
      final needsUpdate = (account.businessName.isNotEmpty &&
              settingsProvider.settings.businessName !=
                  account.businessName) ||
          (account.currency != null &&
              settingsProvider.settings.currency != account.currency) ||
          (account.locale != null &&
              settingsProvider.settings.locale != account.locale);
      if (needsUpdate) {
        await settingsProvider.update(
          settingsProvider.settings.copyWith(
            businessName: account.businessName.isNotEmpty
                ? account.businessName
                : settingsProvider.settings.businessName,
            currency:
                account.currency ?? settingsProvider.settings.currency,
            locale: account.locale ?? settingsProvider.settings.locale,
          ),
        );
      }

      await customerProvider.load();
      await debtProvider.load();
      await orderProvider.load();

      final receivable = await debtProvider.getTotalReceivableCents();
      final payable = await debtProvider.getTotalPayableCents();
      final activeCount = await orderProvider.getActiveCount();

      if (mounted) {
        setState(() {
          _activeOrdersCount = activeCount;
          _receivableCents = receivable;
          _payableCents = payable;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>();
    final customers = context.watch<CustomerProvider>();
    final currency = settings.currency;

    final ownerName = settings.settings.ownerName.trim();
    final businessName = settings.settings.businessName.trim();
    final displayName = _accountName.isNotEmpty
        ? _accountName
        : ownerName.isNotEmpty
            ? ownerName
            : 'Мой профиль';

    final debtValue = _receivableCents > 0
        ? 'вам ${FinancialCalculator.formatCentsCompact(_receivableCents, currency: currency)}'
        : _payableCents > 0
            ? 'вы ${FinancialCalculator.formatCentsCompact(_payableCents, currency: currency)}'
            : null;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 96),
          children: [
            Text(
              'Мой профиль',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        AppAvatar(name: displayName, size: 52),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.divider),
                  _InfoRow(
                    label: 'Имя',
                    value: _accountName.isNotEmpty ? _accountName : ownerName,
                    onTap: _openSettings,
                  ),
                  Divider(height: 1, color: colors.divider),
                  _InfoRow(
                    label: 'Логин',
                    value: _login,
                    onTap: _openSettings,
                  ),
                  Divider(height: 1, color: colors.divider),
                  _InfoRow(
                    label: 'Бизнес',
                    value: businessName,
                    onTap: _openSettings,
                  ),
                  Divider(height: 1, color: colors.divider),
                  _InfoRow(
                    label: 'Валюта',
                    value: settings.currency,
                    onTap: _openSettings,
                  ),
                  Divider(height: 1, color: colors.divider),
                  _InfoRow(
                    label: 'Язык',
                    value: settings.locale == 'ru' ? 'Русский' : 'English',
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuItem(
                    label: 'Клиенты',
                    value: '${customers.totalCount}',
                    onTap: () => context.go('/profile/customers'),
                  ),
                  Divider(height: 1, color: colors.divider),
                  _MenuItem(
                    label: 'Заказы в работе',
                    value: '$_activeOrdersCount',
                    onTap: () => context.go('/orders'),
                  ),
                  Divider(height: 1, color: colors.divider),
                  _MenuItem(
                    label: 'Долги',
                    value: debtValue,
                    onTap: () => context.go('/profile/debts'),
                  ),
                  Divider(height: 1, color: colors.divider),
                  _MenuItem(
                    label: 'Отчёты',
                    onTap: () => context.go('/profile/reports'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Выйти',
              variant: AppButtonVariant.danger,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await context.push('/profile/settings');
    final account = await AccountStore.load();
    if (!mounted) return;
    setState(() {
      _accountName = account.name;
      _login = account.login;
    });
  }

  Future<void> _logout() async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Выйти из аккаунта?',
      message: 'Чтобы снова открыть данные, нужно будет войти.',
      confirmLabel: 'Выйти',
      cancelLabel: 'Остаться',
    );
    if (confirm != true || !mounted) return;
    await AccountStore.clearSession();
    if (mounted) context.go('/login');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final empty = value.trim().isEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
              ),
            ),
            Text(
              empty ? 'Добавить' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: empty ? FontWeight.w600 : FontWeight.w500,
                color: empty ? colors.primary : colors.textSecondary,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.onTap,
    this.value,
  });

  final String label;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
