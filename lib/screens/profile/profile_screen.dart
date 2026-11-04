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
import '../../components/app_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeOrdersCount = 0;
  int _receivableCents = 0;
  int _payableCents = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CustomerProvider>().load();
      await context.read<DebtProvider>().load();

      final orderProvider = context.read<OrderProvider>();
      await orderProvider.load();

      final debtProvider = context.read<DebtProvider>();
      final receivable =
          await debtProvider.getTotalReceivableCents();
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

    final businessName = settings.settings.businessName.isNotEmpty
        ? settings.settings.businessName
        : 'Мой бизнес';
    final ownerName = settings.settings.ownerName.isNotEmpty
        ? settings.settings.ownerName
        : null;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Профиль',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/profile/settings'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(Icons.settings_outlined,
                            size: 20, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Business card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                child: AppCard(
                  child: Row(
                    children: [
                      AppAvatar(
                          name: businessName,
                          size: 56),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (ownerName != null)
                              Text(
                                ownerName,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary),
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            GestureDetector(
                              onTap: () =>
                                  context.go('/profile/settings'),
                              child: Text(
                                'Редактировать профиль',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Quick stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Клиентов',
                        value: '${customers.totalCount}',
                        icon: Icons.people_outline_rounded,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatTile(
                        label: 'Активных заказов',
                        value: '$_activeOrdersCount',
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_receivableCents > 0 || _payableCents > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
                  child: Row(
                    children: [
                      if (_receivableCents > 0)
                        Expanded(
                          child: _StatTile(
                            label: 'Мне должны',
                            value: FinancialCalculator.formatCentsCompact(
                                _receivableCents, currency: currency),
                            icon: Icons.trending_up_rounded,
                            color: colors.income,
                          ),
                        ),
                      if (_receivableCents > 0 && _payableCents > 0)
                        const SizedBox(width: AppSpacing.sm),
                      if (_payableCents > 0)
                        Expanded(
                          child: _StatTile(
                            label: 'Я должен',
                            value: FinancialCalculator.formatCentsCompact(
                                _payableCents, currency: currency),
                            icon: Icons.trending_down_rounded,
                            color: colors.expense,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Menu items
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Управление',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.people_outline_rounded,
                            label: 'Клиенты',
                            value: '${customers.totalCount}',
                            iconColor: colors.primary,
                            onTap: () =>
                                context.go('/profile/customers'),
                          ),
                          Divider(
                              height: 1,
                              indent: AppSpacing.xl + 36,
                              color: colors.divider),
                          _MenuItem(
                            icon:
                                Icons.account_balance_wallet_outlined,
                            label: 'Долги',
                            iconColor: colors.warning,
                            onTap: () =>
                                context.go('/profile/debts'),
                          ),
                          Divider(
                              height: 1,
                              indent: AppSpacing.xl + 36,
                              color: colors.divider),
                          _MenuItem(
                            icon: Icons.bar_chart_rounded,
                            label: 'Отчёты',
                            iconColor: const Color(0xFF8B5CF6),
                            onTap: () =>
                                context.go('/profile/reports'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Настройки',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.settings_outlined,
                            label: 'Настройки',
                            iconColor: colors.textSecondary,
                            onTap: () =>
                                context.go('/profile/settings'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                      fontSize: 13, color: colors.textMuted),
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
