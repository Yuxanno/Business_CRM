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
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';
import '../../components/app_card.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    await provider.loadMonth(
      provider.selectedYear != 0 ? provider.selectedYear : now.year,
      provider.selectedMonth != 0 ? provider.selectedMonth : now.month,
    );
  }

  Future<void> _reload() async {
    await context.read<FinanceProvider>().reload();
  }

  Future<void> _shiftMonth(int delta) async {
    final provider = context.read<FinanceProvider>();
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<FinanceProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Compact header ─────────────────────────────────────────────
            _FinanceHeader(
              provider: provider,
              currency: currency,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
            // ── Tabs ───────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Операции'),
                Tab(text: 'Доходы'),
                Tab(text: 'Расходы'),
              ],
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? const SingleChildScrollView(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: AppSkeletonList(count: 4),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _TransactionsTab(
                          provider: provider,
                          currency: currency,
                          onReload: _reload,
                        ),
                        _FilteredTransactionsTab(
                          provider: provider,
                          type: TransactionType.income,
                          currency: currency,
                          onReload: _reload,
                        ),
                        _FilteredTransactionsTab(
                          provider: provider,
                          type: TransactionType.expense,
                          currency: currency,
                          onReload: _reload,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Finance Header (title + month nav + summary) ─────────────────────────────

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({
    required this.provider,
    required this.currency,
    required this.onPrev,
    required this.onNext,
  });

  final FinanceProvider provider;
  final String currency;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final isCurrentMonth = provider.selectedYear == now.year &&
        provider.selectedMonth == now.month;
    final net = provider.incomeCents - provider.expenseCents;
    final isPositive = net >= 0;

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Деньги',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                // Month navigator — compact inline
                _MonthPill(
                  year: provider.selectedYear,
                  month: provider.selectedMonth,
                  isCurrentMonth: isCurrentMonth,
                  onPrev: onPrev,
                  onNext: onNext,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Summary strip — horizontal scroll so it never overflows
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              children: [
                _SummaryChip(
                  label: 'Доходы',
                  amount: FinancialCalculator.formatCents(
                      provider.incomeCents, currency: currency),
                  color: colors.income,
                  icon: Icons.arrow_downward_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
                _SummaryChip(
                  label: 'Расходы',
                  amount: FinancialCalculator.formatCents(
                      provider.expenseCents, currency: currency),
                  color: colors.expense,
                  icon: Icons.arrow_upward_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
                _SummaryChip(
                  label: isPositive ? 'Прибыль' : 'Убыток',
                  amount: FinancialCalculator.formatCents(
                      net.abs(), currency: currency),
                  color: isPositive ? colors.income : colors.expense,
                  icon: isPositive
                      ? Icons.account_balance_outlined
                      : Icons.trending_down_rounded,
                  highlight: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ─── Month pill with prev/next ─────────────────────────────────────────────────

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            enabled: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              DateHelper.formatMonthYear(DateTime(year, month)),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          _PillBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            enabled: !isCurrentMonth,
          ),
        ],
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? colors.textSecondary : colors.textMuted,
        ),
      ),
    );
  }
}

// ─── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.08)
            : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.25) : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.textMuted,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: highlight ? color : colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.provider,
    required this.currency,
    required this.onReload,
  });

  final FinanceProvider provider;
  final String currency;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async => onReload(),
      child: CustomScrollView(
        slivers: [
          if (provider.transactions.isEmpty)
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'В этом месяце пусто',
                subtitle: 'Нажмите + чтобы добавить доход или расход',
                actionLabel: 'Добавить доход',
                onAction: () => context.push('/finance/new?type=income'),
              ),
            )
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 100),
              sliver: _TransactionSliver(
                transactions: provider.transactions,
                currency: currency,
                onDelete: (tx) async {
                  final confirm = await showConfirmSheet(
                    context: context,
                    title: 'Удалить операцию?',
                    message: 'Это действие нельзя отменить.',
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<FinanceProvider>().delete(tx.id);
                  }
                },
                onEdit: (tx) => context.push('/finance/edit/${tx.id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Filtered Transactions Tab (Доходы / Расходы) ────────────────────────────

class _FilteredTransactionsTab extends StatelessWidget {
  const _FilteredTransactionsTab({
    required this.provider,
    required this.type,
    required this.currency,
    required this.onReload,
  });

  final FinanceProvider provider;
  final TransactionType type;
  final String currency;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filtered = provider.transactions
        .where((t) => t.type == type)
        .toList();

    final emptyTitle = type == TransactionType.income
        ? 'Нет доходов за этот период'
        : 'Нет расходов за этот период';
    final newRoute = type == TransactionType.income
        ? '/finance/new?type=income'
        : '/finance/new?type=expense';
    final actionLabel = type == TransactionType.income
        ? 'Добавить доход'
        : 'Добавить расход';

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async => onReload(),
      child: CustomScrollView(
        slivers: [
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: AppEmptyState(
                icon: type == TransactionType.income
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                title: emptyTitle,
                subtitle: 'Нажмите + чтобы добавить операцию',
                actionLabel: actionLabel,
                onAction: () => context.push(newRoute),
              ),
            )
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 100),
              sliver: _TransactionSliver(
                transactions: filtered,
                currency: currency,
                onDelete: (tx) async {
                  final confirm = await showConfirmSheet(
                    context: context,
                    title: 'Удалить операцию?',
                    message: 'Это действие нельзя отменить.',
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<FinanceProvider>().delete(tx.id);
                  }
                },
                onEdit: (tx) => context.push('/finance/edit/${tx.id}'),
              ),
            ),
          ],
        ],
      ),
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
    final colors = context.appColors;

    // Group by date
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

          // Day total
          final dayIncome = txs
              .where((t) => t.type == TransactionType.income)
              .fold(0, (s, t) => s + t.amountCents);
          final dayExpense = txs
              .where((t) => t.type == TransactionType.expense)
              .fold(0, (s, t) => s + t.amountCents);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.only(
                    top: AppSpacing.md, bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      dateKey,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (dayIncome > 0)
                      Text(
                        '+${FinancialCalculator.formatCentsCompact(dayIncome)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.income,
                        ),
                      ),
                    if (dayIncome > 0 && dayExpense > 0)
                      Text(
                        '  ·  ',
                        style: TextStyle(
                            fontSize: 11, color: colors.textMuted),
                      ),
                    if (dayExpense > 0)
                      Text(
                        '−${FinancialCalculator.formatCentsCompact(dayExpense)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.expense,
                        ),
                      ),
                  ],
                ),
              ),
              // Transactions card
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int j = 0; j < txs.length; j++) ...[
                      if (j > 0)
                        Divider(
                          height: 1,
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                          color: colors.divider,
                        ),
                      _TransactionTile(
                        tx: txs[j],
                        currency: currency,
                        onDelete: () => onDelete(txs[j]),
                        onEdit: () => onEdit(txs[j]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        childCount: keys.length,
      ),
    );
  }
}

// ─── Transaction Tile (inside card) ──────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
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
    final tileColor = isIncome ? colors.income : colors.expense;
    final sign = isIncome ? '+' : '−';
    final label = tx.description?.isNotEmpty == true
        ? tx.description!
        : _categoryLabel(tx.category) ?? 'Операция';

    return Slidable(
      endActionPane: isLinked
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.40,
              children: [
                SlidableAction(
                  onPressed: (_) => onEdit(),
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Изменить',
                ),
                SlidableAction(
                  onPressed: (_) => onDelete(),
                  backgroundColor: colors.expense,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_outline_rounded,
                  label: 'Удалить',
                ),
              ],
            ),
      child: InkWell(
        onTap: isLinked ? null : onEdit,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              // Icon
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
                  size: 15,
                  color: tileColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isLinked
                          ? (tx.linkedEntityType == 'order_payment'
                              ? 'Платёж по заказу'
                              : 'Связано с долгом')
                          : DateHelper.relativeDate(tx.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${FinancialCalculator.formatCents(tx.amountCents, currency: currency)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tileColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isLinked)
                    Icon(Icons.link_rounded,
                        size: 12, color: colors.textMuted),
                ],
              ),
            ],
          ),
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
