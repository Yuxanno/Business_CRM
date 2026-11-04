import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_chip.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/category_chart_widget.dart';
import '../../components/finance_bar_chart.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonth();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    final provider = context.read<FinanceProvider>();
    final now = DateTime.now();
    await provider.loadMonth(provider.selectedYear != 0 ? provider.selectedYear : now.year,
        provider.selectedMonth != 0 ? provider.selectedMonth : now.month);
    final data = await provider.getDailyTotals();
    if (mounted) setState(() => _chartData = data);
  }

  Future<void> _reload() async {
    final provider = context.read<FinanceProvider>();
    await provider.reload();
    final data = await provider.getDailyTotals();
    if (mounted) setState(() => _chartData = data);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<FinanceProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Финансы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/finance/new'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Операции'),
            Tab(text: 'Доходы'),
            Tab(text: 'Расходы'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month navigator
          _MonthNavigator(
            year: provider.selectedYear,
            month: provider.selectedMonth,
            onPrev: () => _shiftMonth(provider, -1),
            onNext: () => _shiftMonth(provider, 1),
          ),
          // Summary row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
            child: _SummaryRow(
              incomeCents: provider.incomeCents,
              expenseCents: provider.expenseCents,
              currency: currency,
            ),
          ),
          // Tab views
          Expanded(
            child: provider.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 0 — All transactions
                      _TransactionsTab(
                        provider: provider,
                        currency: currency,
                        chartData: _chartData,
                        onReload: _reload,
                      ),
                      // Tab 1 — Income analytics
                      _AnalyticsTab(
                        transactions: provider.transactions,
                        type: TransactionType.income,
                        currency: currency,
                        chartData: _chartData,
                        year: provider.selectedYear,
                        month: provider.selectedMonth,
                      ),
                      // Tab 2 — Expense analytics
                      _AnalyticsTab(
                        transactions: provider.transactions,
                        type: TransactionType.expense,
                        currency: currency,
                        chartData: _chartData,
                        year: provider.selectedYear,
                        month: provider.selectedMonth,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _shiftMonth(FinanceProvider provider, int delta) async {
    var month = provider.selectedMonth + delta;
    var year = provider.selectedYear;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    await provider.loadMonth(year, month);
    final data = await provider.getDailyTotals();
    if (mounted) setState(() => _chartData = data);
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.provider,
    required this.currency,
    required this.chartData,
    required this.onReload,
  });

  final FinanceProvider provider;
  final String currency;
  final List<Map<String, dynamic>> chartData;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async => onReload(),
      child: CustomScrollView(
        slivers: [
          // Type filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
              child: Row(
                children: [
                  AppFilterChip(
                    label: 'Все',
                    selected: provider.typeFilter == null,
                    onTap: () => provider.setTypeFilter(null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Доходы',
                    selected: provider.typeFilter == TransactionType.income,
                    onTap: () =>
                        provider.setTypeFilter(TransactionType.income),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppFilterChip(
                    label: 'Расходы',
                    selected: provider.typeFilter == TransactionType.expense,
                    onTap: () =>
                        provider.setTypeFilter(TransactionType.expense),
                  ),
                ],
              ),
            ),
          ),
          if (provider.transactions.isEmpty)
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Нет операций',
                subtitle: 'Добавьте первый доход или расход',
                actionLabel: 'Добавить',
                onAction: () => context.go('/finance/new'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 80),
              sliver: _TransactionSliver(
                transactions: provider.transactions,
                currency: currency,
                onDelete: (tx) async {
                  final confirm = await showConfirmSheet(
                    context: context,
                    title: 'Удалить операцию?',
                    message: 'Это действие нельзя отменить.',
                  );
                  if (confirm == true) {
                    await context.read<FinanceProvider>().delete(tx.id);
                  }
                },
                onEdit: (tx) => context.go('/finance/edit/${tx.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({
    required this.transactions,
    required this.type,
    required this.currency,
    required this.chartData,
    required this.year,
    required this.month,
  });

  final List<AppTransaction> transactions;
  final TransactionType type;
  final String currency;
  final List<Map<String, dynamic>> chartData;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filtered = transactions.where((t) => t.type == type).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 80),
      children: [
        // Bar chart
        if (chartData.isNotEmpty) ...[
          Text(
            'График по дням',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: FinanceBarChart(
              dailyData: chartData
                  .where((d) => d['type'] == type.toStoredString())
                  .toList(),
              year: year,
              month: month,
              currency: currency,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        // Pie chart by category
        Text(
          'По категориям',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      type == TransactionType.income
                          ? 'Нет доходов за этот период'
                          : 'Нет расходов за этот период',
                      style: TextStyle(
                          fontSize: 13, color: colors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : CategoryChartWidget(
                  transactions: filtered,
                  type: type,
                  currency: currency,
                ),
        ),
      ],
    );
  }
}

// ─── Transaction Sliver (grouped by date) ─────────────────────────────────────

class _TransactionSliver extends StatelessWidget {
  const _TransactionSliver({
    required this.transactions,
    required this.currency,
    required this.onDelete,
    required this.onEdit,
  });

  final List<AppTransaction> transactions;
  final String currency;
  final ValueChanged<AppTransaction> onDelete;
  final ValueChanged<AppTransaction> onEdit;

  @override
  Widget build(BuildContext context) {
    // Group by date string
    final Map<String, List<AppTransaction>> grouped = {};
    for (final tx in transactions) {
      final key = DateHelper.formatDate(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    final keys = grouped.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final dateKey = keys[i];
          final txs = grouped[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  dateKey,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
              ...txs.map((tx) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TransactionCard(
                      tx: tx,
                      currency: currency,
                      onDelete: () => onDelete(tx),
                      onEdit: () => onEdit(tx),
                    ),
                  )),
            ],
          );
        },
        childCount: keys.length,
      ),
    );
  }
}

// ─── Month Navigator ──────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onPrev,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  color: colors.textSecondary),
            ),
          ),
          Text(
            DateHelper.formatMonthYear(DateTime(year, month)),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: isCurrentMonth ? null : onNext,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? colors.surfaceSecondary.withOpacity(0.5)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: isCurrentMonth
                      ? colors.textMuted
                      : colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.incomeCents,
    required this.expenseCents,
    required this.currency,
  });

  final int incomeCents;
  final int expenseCents;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final net = incomeCents - expenseCents;
    final isPositive = net >= 0;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Доходы',
            value: FinancialCalculator.formatCents(incomeCents,
                currency: currency),
            color: colors.income,
            icon: Icons.trending_up_rounded,
            bg: colors.incomeBackground,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            label: 'Расходы',
            value: FinancialCalculator.formatCents(expenseCents,
                currency: currency),
            color: colors.expense,
            icon: Icons.trending_down_rounded,
            bg: colors.expenseBackground,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            label: isPositive ? 'Прибыль' : 'Убыток',
            value: FinancialCalculator.formatCents(net.abs(),
                currency: currency),
            color: isPositive ? colors.income : colors.expense,
            icon: isPositive
                ? Icons.account_balance_outlined
                : Icons.warning_amber_rounded,
            bg: isPositive
                ? colors.incomeBackground
                : colors.expenseBackground,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.bg,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.tx,
    required this.currency,
    required this.onDelete,
    required this.onEdit,
  });

  final AppTransaction tx;
  final String currency;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = tx.type == TransactionType.income;
    final isLinked = tx.linkedEntityType == 'order_payment' ||
        tx.linkedEntityType == 'debt_payment';

    return Slidable(
      endActionPane: isLinked
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => onEdit(),
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Изменить',
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                SlidableAction(
                  onPressed: (_) => onDelete(),
                  backgroundColor: colors.expense,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline_rounded,
                  label: 'Удалить',
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ],
            ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                    tx.description ??
                        _categoryLabel(tx.category) ??
                        'Операция',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx.category != null && tx.description != null)
                    Text(
                      _categoryLabel(tx.category) ?? tx.category!,
                      style: TextStyle(
                          fontSize: 11, color: colors.textMuted),
                    ),
                  if (isLinked)
                    Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: 11, color: colors.textMuted),
                        const SizedBox(width: 2),
                        Text(
                          tx.linkedEntityType == 'order_payment'
                              ? 'Платёж по заказу'
                              : 'Платёж по долгу',
                          style: TextStyle(
                              fontSize: 11, color: colors.textMuted),
                        ),
                      ],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _categoryLabel(String? category) {
    if (category == null) return null;
    const labels = {
      'order_payment': 'Оплата заказа',
      'service': 'Услуга',
      'sale': 'Продажа',
      'refund_received': 'Возврат',
      'other_income': 'Прочий доход',
      'supplies': 'Материалы',
      'rent': 'Аренда',
      'utilities': 'Коммунальные услуги',
      'transport': 'Транспорт',
      'marketing': 'Маркетинг',
      'salary': 'Зарплата',
      'equipment': 'Оборудование',
      'other_expense': 'Прочий расход',
      'debt_received': 'Получен долг',
      'debt_paid': 'Выплата долга',
    };
    return labels[category];
  }
}
