import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';
import 'account_store.dart';

const double _kPagePadding = 20.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    final results = await Future.wait([
      AccountStore.load(),
      dashboardProvider.loadSummaryOnly(),
    ]);
    if (!mounted) return;
    final account = results[0] as AccountInfo;

    setState(() {
      _accountName = account.name;
      _login = account.login;
      _activeOrdersCount = dashboardProvider.activeOrdersCount;
      _receivableCents = dashboardProvider.receivableCents;
      _payableCents = dashboardProvider.payableCents;
    });

    final needsUpdate = (account.businessName.isNotEmpty &&
            settingsProvider.settings.businessName != account.businessName) ||
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
          currency: account.currency ?? settingsProvider.settings.currency,
          locale: account.locale ?? settingsProvider.settings.locale,
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    await context.push('/profile/settings');
    final account = await AccountStore.load();
    if (!mounted) return;
    setState(() {
      _accountName = account.name;
      _login = account.login;
    });
  }

  Future<void> _logout() async {
    HapticFeedback.selectionClick();
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Выйти из аккаунта?', 'Sign out?'),
      message: context.tr(
          'Чтобы снова открыть данные, нужно будет войти в профиль.',
          'You will need to sign in again to access your data.'),
      confirmLabel: context.tr('Выйти', 'Sign out'),
      cancelLabel: context.tr('Остаться', 'Stay'),
    );
    if (confirm != true || !mounted) return;
    await AccountStore.clearSession();
    if (mounted) context.go('/login');
  }

  Future<void> _deleteAccount() async {
    HapticFeedback.selectionClick();
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить аккаунт?', 'Delete account?'),
      message: context.tr(
        'Аккаунт и все данные (клиенты, заказы, операции, долги) будут удалены безвозвратно.',
        'Your account and all data (customers, orders, transactions, debts) will be permanently deleted.',
      ),
      confirmLabel: context.tr('Удалить', 'Delete'),
      cancelLabel: context.tr('Отмена', 'Cancel'),
    );
    if (confirm != true || !mounted) return;

    final passwordCtrl = TextEditingController();
    String? errorText;
    var submitting = false;

    final deleted = await showAppModal<bool>(
      context: context,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = sheetCtx.appColors;

          Future<void> submitDelete() async {
            if (submitting) return;
            final pwd = passwordCtrl.text;
            if (pwd.isEmpty) {
              setSheetState(() {
                errorText = sheetCtx.tr(
                  'Введите пароль от аккаунта',
                  'Enter your account password',
                );
              });
              return;
            }
            setSheetState(() {
              submitting = true;
              errorText = null;
            });
            final err = await AccountStore.deleteAccount(password: pwd);
            if (!sheetCtx.mounted) return;
            if (err != null) {
              setSheetState(() {
                submitting = false;
                errorText = err;
              });
              return;
            }
            Navigator.of(sheetCtx, rootNavigator: true).pop(true);
          }

          return AppModalSheet(
            title: sheetCtx.tr('Подтвердите паролем', 'Confirm with password'),
            subtitle: sheetCtx.tr(
              'Введите пароль от аккаунта, чтобы навсегда удалить все данные',
              'Enter your account password to permanently delete all data',
            ),
            headerIcon: Icons.lock_outline_rounded,
            headerColor: colors.expense,
            bottomBar: FormSubmitButton(
              label: sheetCtx.tr('Удалить аккаунт', 'Delete account'),
              accentColor: colors.expense,
              isLoading: submitting,
              icon: Icons.delete_forever_rounded,
              onPressed: submitDelete,
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetField(
                    label: sheetCtx.tr('ПАРОЛЬ', 'PASSWORD'),
                    required: true,
                    child: FormTextField(
                      controller: passwordCtrl,
                      prefixIcon: Icons.lock_outline_rounded,
                      hint: sheetCtx.tr(
                        'Введите текущий пароль...',
                        'Enter current password...',
                      ),
                      obscureText: true,
                      autofocus: true,
                      onFieldSubmitted: (_) => submitDelete(),
                    ),
                  ),
                  if (errorText != null) FormFieldError(text: errorText!),
                ],
              ),
            ),
          );
        },
      ),
    );

    passwordCtrl.dispose();
    if (deleted == true && mounted) {
      HapticFeedback.mediumImpact();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final currency = settings.currency;

    final ownerName = settings.settings.ownerName.trim();
    final businessName = settings.settings.businessName.trim();
    final displayName = _accountName.isNotEmpty
        ? _accountName
        : ownerName.isNotEmpty
            ? ownerName
            : context.tr('Мой профиль', 'My profile');

    final debtSubtitle = _receivableCents > 0
        ? context.tr(
            'Нам: ${FinancialCalculator.formatCentsCompact(_receivableCents, currency: currency)}',
            'Owed: ${FinancialCalculator.formatCentsCompact(_receivableCents, currency: currency)}')
        : _payableCents > 0
            ? context.tr(
                'Мы: ${FinancialCalculator.formatCentsCompact(_payableCents, currency: currency)}',
                'We owe: ${FinancialCalculator.formatCentsCompact(_payableCents, currency: currency)}')
            : context.tr('Расчёты и балансы', 'Balances & tracking');

    final totalCategories =
        settings.incomeCategories.length + settings.expenseCategories.length;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              _kPagePadding,
              AppSpacing.md,
              _kPagePadding,
              48,
            ),
            children: [
              // ── 1. Top Header ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Ещё', 'More'),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openSettings,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('Настройки', 'Settings'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── 2. Business & Owner Card (tap to open Profile) ─────────────
              _BusinessProfileCard(
                displayName: displayName,
                businessName: businessName,
                login: _login,
                currency: settings.currency,
                languageLabel: settings.locale == 'ru' ? 'Русский' : 'English',
                onDetails: () {
                  HapticFeedback.selectionClick();
                  context.push('/profile/details');
                },
              ),

              const SizedBox(height: 20),

              // ── 3. Quick CRM Sections (2x2 Grid) ───────────────────────────
              _HubSectionTitle(
                  context.tr('Разделы бизнеса', 'Business sections')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HubTileCard(
                      icon: Icons.people_outline_rounded,
                      title: context.tr('Клиенты', 'Customers'),
                      subtitle: context.tr('База контактов', 'Contacts'),
                      badgeText: '${dashboard.totalCustomersCount}',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go('/profile/customers');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HubTileCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: context.tr('Долги', 'Debts'),
                      subtitle: debtSubtitle,
                      badgeText: (_receivableCents > 0 || _payableCents > 0)
                          ? context.tr('Актив.', 'Active')
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go('/profile/debts');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HubTileCard(
                      icon: Icons.bar_chart_rounded,
                      title: context.tr('Отчёты', 'Reports'),
                      subtitle:
                          context.tr('Итоги по месяцам', 'Monthly summary'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go('/profile/reports');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HubTileCard(
                      icon: Icons.category_outlined,
                      title: context.tr('Категории', 'Categories'),
                      subtitle: context.tr(
                          'Доходы и расходы', 'Income & expenses'),
                      badgeText: '$totalCategories',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go('/profile/categories');
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 4. Active Orders Shortcut ──────────────────────────────────
              AppCard(
                padding: EdgeInsets.zero,
                child: _ProfileNavRow(
                  icon: Icons.receipt_long_outlined,
                  title: context.tr('Заказы в работе', 'Active orders'),
                  subtitle: context.tr(
                      'Активные заказы клиентов', 'Ongoing customer orders'),
                  trailingBadge: '$_activeOrdersCount',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/orders');
                  },
                ),
              ),

              const SizedBox(height: 18),

              // ── 5. Calm Logout & Delete Account Buttons ────────────────────
              GestureDetector(
                onTap: _logout,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Выйти из аккаунта', 'Sign out'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _deleteAccount,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.expense.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.expense.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: colors.expense,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Удалить аккаунт', 'Delete account'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 1. Business & Owner Profile Card ────────────────────────────────────────

class _BusinessProfileCard extends StatelessWidget {
  const _BusinessProfileCard({
    required this.displayName,
    required this.businessName,
    required this.login,
    required this.currency,
    required this.languageLabel,
    required this.onDetails,
  });

  final String displayName;
  final String businessName;
  final String login;
  final String currency;
  final String languageLabel;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: onDetails,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(name: displayName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      businessName.isNotEmpty
                          ? businessName
                          : (login.isNotEmpty
                              ? '@$login'
                              : context.tr('Открыть профиль', 'Open profile')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickSettingChip(
                  icon: Icons.payments_outlined,
                  label: context.tr('Валюта', 'Currency'),
                  value: currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickSettingChip(
                  icon: Icons.language_rounded,
                  label: context.tr('Язык', 'Language'),
                  value: languageLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickSettingChip extends StatelessWidget {
  const _QuickSettingChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 2. Quick Hub Grid Tile ──────────────────────────────────────────────────

class _HubTileCard extends StatelessWidget {
  const _HubTileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: colors.primary,
                ),
              ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. Clean Navigation Row ─────────────────────────────────────────────────

class _ProfileNavRow extends StatelessWidget {
  const _ProfileNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingBadge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, size: 18, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  trailingBadge!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubSectionTitle extends StatelessWidget {
  const _HubSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colors.textSecondary,
      ),
    );
  }
}

// Kept for hot-reload compatibility
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
  Widget build(BuildContext context) => const SizedBox.shrink();
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
