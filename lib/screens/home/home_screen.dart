import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/transaction.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_section_header.dart';
import '../../components/app_empty_state.dart';
import '../../components/finance_bar_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dashboard = context.watch<DashboardProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          onRefresh: () => context.read<DashboardProvider>().reload(),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                  child: _Header(
                    dashboard: dashboard,
                    currency: currency,
                  ),
                ),
              ),
              // Main financial card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                  child: _FinancialSummaryCard(
                    dashboard: dashboard,
                    currency: currency,
                  ),
                ),
              ),
              // Quick stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                  child: _QuickStats(
                    dashboard: dashboard,
                    currency: currency,
                  ),
                ),
              ),
              // Chart
              if (dashboard.chartData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(title: 'График месяца'),
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          child: FinanceBarChart(
                            dailyData: dashboard.chartData,
                            year: dashboard.year,
                            month: dashboard.month,
                            currency: currency,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Recent activity
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, 0),
                  child: AppSectionHeader(
                    title: 'Последние операции',
                    action: () => context.go('/finance'),
                    actionLabel: 'Все',
                  ),
                ),
              ),
              if (dashboard.isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (dashboard.recentActivity.isEmpty)
                SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Нет операций',
                    subtitle: 'Добавьте первый доход или расход',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final tx = dashboard.recentActivity[i];
                      return _ActivityItem(tx: tx, currency: currency);
                    },
                    childCount: dashboard.recentActivity.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl + 60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.dashboard, required this.currency});

  final DashboardProvider dashboard;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = context.watch<SettingsProvider>();
    final name = settings.settings.businessName.isNotEmpty
        ? settings.settings.businessName
        : settings.settings.ownerName.isNotEmpty
            ? settings.settings.ownerName
            : 'Бизнес';

    final now = DateTime(dashboard.year, dashboard.month);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateHelper.greeting(),
                style: TextStyle(
                    fontSize: 13, color: colors.textSecondary),
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Month picker
        GestureDetector(
          onTap: () => _pickMonth(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateHelper.formatMonthYear(now),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final dashboard = context.read<DashboardProvider>();
    final year = dashboard.year;
    final months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
        'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];

    final colors = context.appColors;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выберите месяц',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final selected = (i + 1) == dashboard.month;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    dashboard.setMonth(year, i + 1);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary
                          : colors.surfaceSecondary,
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                    ),
                    child: Text(
                      months[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? colors.onPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ─── Financial Summary Card ───────────────────────────────────────────────────

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard(
      {required this.dashboard, required this.currency});

  final DashboardProvider dashboard;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final net = dashboard.netCents;
    final isPositive = net >= 0;

    return AppSummaryCard(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Финансы месяца',
              style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            FinancialCalculator.formatCents(net.abs(), currency: currency),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: isPositive ? colors.income : colors.expense,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            isPositive ? 'Прибыль' : 'Убыток',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _FinMetric(
                  label: 'Доходы',
                  value: FinancialCalculator.formatCents(
                      dashboard.incomeCents, currency: currency),
                  color: colors.income,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: colors.divider),
              Expanded(
                child: _FinMetric(
                  label: 'Расходы',
                  value: FinancialCalculator.formatCents(
                      dashboard.expenseCents, currency: currency),
                  color: colors.expense,
                  icon: Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinMetric extends StatelessWidget {
  const _FinMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted)),
              Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Stats ──────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.dashboard, required this.currency});
  final DashboardProvider dashboard;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Активных заказов',
            value: '${dashboard.activeOrdersCount}',
            icon: Icons.receipt_long_rounded,
            color: colors.primary,
            onTap: () => context.go('/orders'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Дебиторов',
            value: FinancialCalculator.formatCents(
                dashboard.receivableCents, currency: currency),
            icon: Icons.account_balance_wallet_outlined,
            color: colors.warning,
            onTap: () => context.go('/profile/debts'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Клиентов',
            value: '${dashboard.totalCustomersCount}',
            icon: Icons.people_outline_rounded,
            color: colors.income,
            onTap: () => context.go('/profile/customers'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.textMuted),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─── Activity Item ────────────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.tx, required this.currency});
  final AppTransaction tx;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = tx.type == TransactionType.income;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncome
                  ? colors.incomeBackground
                  : colors.expenseBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isIncome ? colors.income : colors.expense,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.category ?? 'Транзакция',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateHelper.relativeDate(tx.date),
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${FinancialCalculator.formatCents(tx.amountCents, currency: currency)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isIncome ? colors.income : colors.expense,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
