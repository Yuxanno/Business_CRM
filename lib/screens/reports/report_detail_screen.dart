import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/category_chart_widget.dart';
import '../../components/finance_bar_chart.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<FinanceProvider>();
    await provider.loadMonth(widget.year, widget.month);
    final data = await provider.getDailyTotals();
    if (mounted) {
      setState(() {
        _chartData = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<FinanceProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    final title = DateHelper.formatMonthYear(
        DateTime(widget.year, widget.month));

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: Text(title)),
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    final net = provider.incomeCents - provider.expenseCents;
    final isProfit = net >= 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Summary card
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isProfit ? 'Прибыль' : 'Убыток',
                      style: TextStyle(
                          fontSize: 14, color: colors.textSecondary),
                    ),
                    Text(
                      FinancialCalculator.formatCents(net.abs(),
                          currency: currency),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isProfit ? colors.income : colors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _FinRow(
                  label: 'Доходы',
                  value: FinancialCalculator.formatCents(
                      provider.incomeCents, currency: currency),
                  color: colors.income,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FinRow(
                  label: 'Расходы',
                  value: FinancialCalculator.formatCents(
                      provider.expenseCents, currency: currency),
                  color: colors.expense,
                ),
                if (provider.incomeCents > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (provider.expenseCents / provider.incomeCents)
                          .clamp(0.0, 1.0),
                      backgroundColor: colors.incomeBackground,
                      valueColor:
                          AlwaysStoppedAnimation(colors.expense),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Расходы: ${FinancialCalculator.percentage(provider.expenseCents, provider.incomeCents).toStringAsFixed(1)}% от доходов',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Bar chart
          if (_chartData.isNotEmpty) ...[
            Text(
              'Доходы и расходы по дням',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: FinanceBarChart(
                dailyData: _chartData,
                year: widget.year,
                month: widget.month,
                currency: currency,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // Income by category
          if (provider.incomeCents > 0) ...[
            Text(
              'Доходы по категориям',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: CategoryChartWidget(
                transactions: provider.transactions,
                type: TransactionType.income,
                currency: currency,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // Expense by category
          if (provider.expenseCents > 0) ...[
            Text(
              'Расходы по категориям',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: CategoryChartWidget(
                transactions: provider.transactions,
                type: TransactionType.expense,
                currency: currency,
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FinRow extends StatelessWidget {
  const _FinRow(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: colors.textSecondary)),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            )),
      ],
    );
  }
}
