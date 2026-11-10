import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_skeleton.dart';
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
    setState(() => _loading = true);
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
    final title =
        DateHelper.formatMonthYear(DateTime(widget.year, widget.month));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/profile/reports'),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 22, color: colors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                      child: const AppSkeletonList(),
                    )
                  : _buildContent(
                      context, provider, currency, title, colors),
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
    String title,
    dynamic colors,
  ) {
    final net = provider.incomeCents - provider.expenseCents;
    final isProfit = net >= 0;
    final isEmpty =
        provider.incomeCents == 0 && provider.expenseCents == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, 100),
      children: [
        // ── Summary card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfit
                  ? [const Color(0xFF065F46), const Color(0xFF047857)]
                  : [const Color(0xFF881337), const Color(0xFFBE123C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.cardLarge),
            boxShadow: [
              BoxShadow(
                color: (isProfit
                        ? AppColors.income
                        : AppColors.expense)
                    .withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isProfit ? 'Прибыль' : 'Убыток',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              isEmpty
                  ? Text(
                      'Нет данных за этот месяц',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                    )
                  : Text(
                      FinancialCalculator.formatCents(net.abs(),
                          currency: currency),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isProfit
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFCA5A5),
                        letterSpacing: -1.2,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
              const SizedBox(height: AppSpacing.md),
              Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: 'Доходы',
                      value: FinancialCalculator.formatCents(
                          provider.incomeCents, currency: currency),
                      color: const Color(0xFF34D399),
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Расходы',
                      value: FinancialCalculator.formatCents(
                          provider.expenseCents, currency: currency),
                      color: const Color(0xFFFCA5A5),
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                ],
              ),
              // Expense ratio bar
              if (provider.incomeCents > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Divider(
                    color: Colors.white.withValues(alpha: 0.12),
                    height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (provider.expenseCents /
                                  provider.incomeCents)
                              .clamp(0.0, 1.0),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                            const Color(0xFFFCA5A5),
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${FinancialCalculator.percentage(provider.expenseCents, provider.incomeCents).toStringAsFixed(0)}% расходов',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Bar chart ───────────────────────────────────────────────────
        if (_chartData.isNotEmpty) ...[
          _SectionTitle('По дням'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: FinanceBarChart(
              dailyData: _chartData,
              year: widget.year,
              month: widget.month,
              currency: currency,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Income by category ──────────────────────────────────────────
        if (provider.incomeCents > 0) ...[
          _SectionTitle('Доходы по категориям'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: CategoryChartWidget(
              transactions: provider.transactions,
              type: TransactionType.income,
              currency: currency,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Expense by category ─────────────────────────────────────────
        if (provider.expenseCents > 0) ...[
          _SectionTitle('Расходы по категориям'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: CategoryChartWidget(
              transactions: provider.transactions,
              type: TransactionType.expense,
              currency: currency,
            ),
          ),
        ],

        if (isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Center(
              child: Text(
                'В этом месяце операций не было',
                style: TextStyle(
                    fontSize: 14, color: colors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: colors.textPrimary,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.45),
                  )),
              Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
