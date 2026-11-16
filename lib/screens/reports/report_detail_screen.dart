import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_skeleton.dart';
import '../../components/category_chart_widget.dart';
import '../../components/finance_bar_chart.dart';

const double _kPagePadding = 20.0;

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  List<Map<String, dynamic>> _chartData = [];
  bool _loading = true;
  TransactionType _selectedCategoryType = TransactionType.income;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<FinanceProvider>();
    await provider.loadMonthFull(widget.year, widget.month);
    final data = await provider.getDailyTotals();
    if (mounted) {
      setState(() {
        _chartData = data;
        // Default to Доходы unless only Расходы has data
        if (provider.incomeCents == 0 && provider.expenseCents > 0) {
          _selectedCategoryType = TransactionType.expense;
        } else {
          _selectedCategoryType = TransactionType.income;
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<FinanceProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final title =
        DateHelper.formatMonthYear(DateTime(widget.year, widget.month));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Clean Top Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/profile/reports');
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Content ─────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: _kPagePadding),
                      child: AppSkeletonList(count: 4),
                    )
                  : _buildContent(context, provider, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FinanceProvider provider,
    String currency,
  ) {
    final colors = context.appColors;
    final isEmpty = provider.incomeCents == 0 && provider.expenseCents == 0;

    if (isEmpty) {
      return AppEmptyState(
        icon: Icons.insights_outlined,
        title: context.tr(
          'В этом месяце операций не было',
          'No transactions this month',
        ),
        subtitle: context.tr(
          'Добавьте доходы или расходы за этот месяц, чтобы увидеть графики и статистику',
          'Add income or expenses for this month to see charts and statistics',
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          _kPagePadding,
          4,
          _kPagePadding,
          80,
        ),
        children: [
          // ── 1. Calm Month Summary Card ─────────────────────────────────
          _MonthReportSummaryCard(
            incomeCents: provider.incomeCents,
            expenseCents: provider.expenseCents,
            transactionsCount: provider.transactions.length,
            currency: currency,
          ),

          const SizedBox(height: 18),

          // ── 2. Daily Dynamics Chart ────────────────────────────────────
          if (_chartData.isNotEmpty) ...[
            _ReportSectionTitle(
                context.tr('Динамика по дням', 'Daily dynamics')),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: FinanceBarChart(
                dailyData: _chartData,
                year: widget.year,
                month: widget.month,
                currency: currency,
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── 3. Unified Category Structure Card ─────────────────────────
          _ReportSectionTitle(
              context.tr('Структура по категориям', 'Category breakdown')),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Calm switcher between Расходы and Доходы
                if (provider.incomeCents > 0 && provider.expenseCents > 0) ...[
                  _CalmCategoryTypeSwitch(
                    selected: _selectedCategoryType,
                    onChanged: (type) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategoryType = type);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                CategoryChartWidget(
                  key: ValueKey('cat_${_selectedCategoryType.name}'),
                  transactions: provider.transactions,
                  type: _selectedCategoryType,
                  currency: currency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 1. Calm Month Summary Card ──────────────────────────────────────────────

class _MonthReportSummaryCard extends StatelessWidget {
  const _MonthReportSummaryCard({
    required this.incomeCents,
    required this.expenseCents,
    required this.transactionsCount,
    required this.currency,
  });

  final int incomeCents;
  final int expenseCents;
  final int transactionsCount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final net = incomeCents - expenseCents;
    final isProfit = net >= 0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isProfit
                    ? context.tr(
                        'Чистая прибыль за месяц',
                        'Net profit for the month',
                      )
                    : context.tr('Итог за месяц', 'Monthly net'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  context.tr(
                    'Операций: $transactionsCount',
                    'Transactions: $transactionsCount',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isProfit ? '+' : '−'}${FinancialCalculator.formatCents(net.abs(), currency: currency)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MonthMetricColumn(
                  label: context.tr('Доходы', 'Income'),
                  amount: FinancialCalculator.formatCents(
                    incomeCents,
                    currency: currency,
                  ),
                  dotColor: colors.income,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: colors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _MonthMetricColumn(
                  label: context.tr('Расходы', 'Expenses'),
                  amount: FinancialCalculator.formatCents(
                    expenseCents,
                    currency: currency,
                  ),
                  dotColor: colors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthMetricColumn extends StatelessWidget {
  const _MonthMetricColumn({
    required this.label,
    required this.amount,
    required this.dotColor,
  });

  final String label;
  final String amount;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 2. Calm Category Type Switcher ──────────────────────────────────────────

class _CalmCategoryTypeSwitch extends StatelessWidget {
  const _CalmCategoryTypeSwitch({
    required this.selected,
    required this.onChanged,
  });

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = selected == TransactionType.income;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: isIncome ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(TransactionType.income),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isIncome ? FontWeight.w700 : FontWeight.w600,
                        color: isIncome ? Colors.white : colors.textSecondary,
                      ),
                      child: Text(context.tr('Доходы', 'Income')),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(TransactionType.expense),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            !isIncome ? FontWeight.w700 : FontWeight.w600,
                        color: !isIncome ? Colors.white : colors.textSecondary,
                      ),
                      child: Text(context.tr('Расходы', 'Expenses')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: colors.textPrimary,
      ),
    );
  }
}
