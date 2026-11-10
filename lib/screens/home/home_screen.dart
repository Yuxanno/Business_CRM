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
import '../../components/app_empty_state.dart';
import '../../components/finance_bar_chart.dart';
import '../../components/app_skeleton.dart';
import '../../components/app_templates.dart';

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
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                  child: _Header(dashboard: dashboard),
                ),
              ),

              // ── Financial summary ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
                  child: _FinancialCard(
                      dashboard: dashboard, currency: currency),
                ),
              ),

              // ── Quick stats row ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                  child: _QuickStats(
                      dashboard: dashboard, currency: currency),
                ),
              ),

              // ── Bar chart ─────────────────────────────────────────────────
              if (dashboard.chartData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          title: 'Динамика месяца',
                          action: null,
                        ),
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

              // ── Recent activity header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.sm),
                  child: _SectionTitle(
                    title: 'Последние операции',
                    action: () => context.go('/finance'),
                    actionLabel: 'Все',
                  ),
                ),
              ),

              // ── Activity list ─────────────────────────────────────────────
              if (dashboard.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      child: const AppSkeletonList(count: 3),
                    ),
                  ),
                )
              else if (dashboard.recentActivity.isEmpty)
                SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'За этот месяц операций нет',
                    subtitle: 'Доход и расход добавляются в разделе «Деньги»',
                    actionLabel: 'Открыть Деньги',
                    onAction: () => context.go('/finance'),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < dashboard.recentActivity.length;
                              i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: AppSpacing.lg,
                                endIndent: AppSpacing.lg,
                                color: colors.divider,
                              ),
                            _ActivityTile(
                              tx: dashboard.recentActivity[i],
                              currency: currency,
                            ),
                          ],
                        ],
                      ),
                    ),
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

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.actionLabel});
  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: action,
            child: Text(
              actionLabel ?? 'Все',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.dashboard});
  final DashboardProvider dashboard;

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'B',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                DateHelper.greeting(),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        // Month pill
        GestureDetector(
          onTap: () => _pickMonth(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: colors.primary),
                const SizedBox(width: 5),
                Text(
                  DateHelper.formatMonthYear(now),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 14, color: colors.textMuted),
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
    const months = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
    ];
    final colors = context.appColors;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите месяц',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.4,
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      months[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ─── Financial summary card ───────────────────────────────────────────────────

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.dashboard, required this.currency});
  final DashboardProvider dashboard;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final net = dashboard.netCents;
    final isPositive = net >= 0;
    final netColor = isPositive
        ? const Color(0xFF34D399)
        : const Color(0xFFFB7185);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPositive ? 'Прибыль' : 'Убыток',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD1FAE5),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'за месяц',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Net amount
          Text(
            FinancialCalculator.formatCents(net.abs(), currency: currency),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: netColor,
              letterSpacing: -1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),

          const SizedBox(height: AppSpacing.lg),

          // Income / Expense row
          Row(
            children: [
              Expanded(
                child: _FinRow(
                  label: 'Доходы',
                  value: FinancialCalculator.formatCents(
                      dashboard.incomeCents, currency: currency),
                  color: colors.income,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Expanded(
                child: _FinRow(
                  label: 'Расходы',
                  value: FinancialCalculator.formatCents(
                      dashboard.expenseCents, currency: currency),
                  color: const Color(0xFFFB7185),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinRow extends StatelessWidget {
  const _FinRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick stats ──────────────────────────────────────────────────────────────

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
          child: _StatTile(
            icon: Icons.receipt_long_rounded,
            label: 'Заказы',
            value: '${dashboard.activeOrdersCount}',
            color: colors.primary,
            onTap: () => context.go('/orders'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Долги',
            value: FinancialCalculator.formatCentsCompact(
                dashboard.receivableCents, currency: currency),
            color: colors.warning,
            onTap: () => context.go('/profile/debts'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.people_outline_rounded,
            label: 'Клиенты',
            value: '${dashboard.totalCustomersCount}',
            color: colors.income,
            onTap: () => context.go('/profile/customers'),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

// ─── Activity tile ────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.tx, required this.currency});
  final AppTransaction tx;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = tx.type == TransactionType.income;
    final tileColor = isIncome ? colors.income : colors.expense;
    final sign = isIncome ? '+' : '−';
    final label =
        tx.description?.isNotEmpty == true ? tx.description! : tx.category ?? 'Операция';

    return InkWell(
      onTap: () => context.go('/finance'),
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            // Dot indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 16,
                color: tileColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateHelper.relativeDate(tx.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$sign${FinancialCalculator.formatCents(tx.amountCents, currency: currency)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tileColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
