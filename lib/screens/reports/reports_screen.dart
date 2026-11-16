import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_skeleton.dart';

const double _kPagePadding = 20.0;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = TransactionRepository();
  List<_MonthReport> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final months = List.generate(12, (i) {
        var month = now.month - i;
        var year = now.year;
        while (month < 1) {
          month += 12;
          year--;
        }
        return (year: year, month: month);
      });

      final results = await Future.wait(
        months.map((m) => _repo.getMonthSummary(m.year, m.month)),
      );

      final reports = List.generate(
        months.length,
        (i) => _MonthReport(
          year: months[i].year,
          month: months[i].month,
          incomeCents: results[i].incomeCents,
          expenseCents: results[i].expenseCents,
        ),
      );

      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;
    final now = DateTime.now();

    final totalIncome = _reports.fold<int>(0, (s, r) => s + r.incomeCents);
    final totalExpense = _reports.fold<int>(0, (s, r) => s + r.expenseCents);
    final hasAnyData = totalIncome > 0 || totalExpense > 0;

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
                        context.go('/profile');
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
                  Text(
                    context.tr('Отчёты', 'Reports'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _loadReports();
                          },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: _loading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              size: 19,
                              color: colors.textPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Content ─────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _loading
                    ? const Align(
                        key: ValueKey('reports-skeleton'),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: _kPagePadding),
                          child: AppSkeletonList(count: 5),
                        ),
                      )
                    : _error != null
                        ? AppEmptyState(
                            key: const ValueKey('reports-error'),
                            icon: Icons.error_outline_rounded,
                            title: context.tr('Ошибка загрузки', 'Loading error'),
                            subtitle: context.tr(
                              'Попробуйте обновить список отчётов',
                              'Try refreshing the reports list',
                            ),
                            actionLabel: context.tr('Повторить', 'Retry'),
                            onAction: _loadReports,
                          )
                        : !hasAnyData
                            ? AppEmptyState(
                                key: const ValueKey('reports-empty'),
                                icon: Icons.insights_outlined,
                                title: context.tr(
                                  'Отчётов пока нет',
                                  'No reports yet',
                                ),
                                subtitle: context.tr(
                                  'Когда появятся доходы или расходы, здесь сформируется аналитика по месяцам',
                                  'Monthly analytics will appear here once you add income or expenses',
                                ),
                              )
                            : RefreshIndicator(
                                key: const ValueKey('reports-content'),
                                color: colors.primary,
                                backgroundColor: colors.surface,
                                onRefresh: _loadReports,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    _kPagePadding,
                                    4,
                                    _kPagePadding,
                                    100,
                                  ),
                                  itemCount: _reports.length + 1,
                                  itemBuilder: (ctx, i) {
                                    if (i == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 18,
                                        ),
                                        child: _YearSummaryCard(
                                          totalIncome: totalIncome,
                                          totalExpense: totalExpense,
                                          currency: currency,
                                        ),
                                      );
                                    }

                                    final report = _reports[i - 1];
                                    final isCurrent = report.year == now.year &&
                                        report.month == now.month;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: RepaintBoundary(
                                        child: _CalmMonthCard(
                                          report: report,
                                          currency: currency,
                                          isCurrent: isCurrent,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            context.go(
                                              '/profile/reports/${report.year}/${report.month}',
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data Model ──────────────────────────────────────────────────────────────

class _MonthReport {
  const _MonthReport({
    required this.year,
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;
  bool get isProfit => netCents >= 0;
  bool get isEmpty => incomeCents == 0 && expenseCents == 0;
}

// ─── 1. Calm 12-Month Summary Card ───────────────────────────────────────────

class _YearSummaryCard extends StatelessWidget {
  const _YearSummaryCard({
    required this.totalIncome,
    required this.totalExpense,
    required this.currency,
  });

  final int totalIncome;
  final int totalExpense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final net = totalIncome - totalExpense;
    final isProfit = net >= 0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Итог за 12 месяцев', '12-month summary'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isProfit ? '+' : '−'}${FinancialCalculator.formatCents(net.abs(), currency: currency)}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _YearMetricItem(
                  label: context.tr('Доходы', 'Income'),
                  amount: FinancialCalculator.formatCents(
                    totalIncome,
                    currency: currency,
                  ),
                  dotColor: colors.income,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: colors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _YearMetricItem(
                  label: context.tr('Расходы', 'Expenses'),
                  amount: FinancialCalculator.formatCents(
                    totalExpense,
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

class _YearMetricItem extends StatelessWidget {
  const _YearMetricItem({
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

// ─── 2. Calm, Scannable Month Card ───────────────────────────────────────────

class _CalmMonthCard extends StatelessWidget {
  const _CalmMonthCard({
    required this.report,
    required this.currency,
    required this.isCurrent,
    required this.onTap,
  });

  final _MonthReport report;
  final String currency;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEmpty = report.isEmpty;
    final isProfit = report.isProfit;

    final monthNumber = report.month.toString().padLeft(2, '0');
    final monthTitle =
        DateHelper.formatMonthYear(DateTime(report.year, report.month));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Calm Month Number Badge
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent
                  ? colors.primary
                  : (isEmpty ? colors.background : colors.surfaceSecondary),
              borderRadius: BorderRadius.circular(10),
              border: isCurrent ? null : Border.all(color: colors.border),
            ),
            child: Text(
              monthNumber,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrent
                    ? Colors.white
                    : (isEmpty ? colors.textMuted : colors.textPrimary),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Month Name + Calm Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isEmpty ? colors.textSecondary : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEmpty
                      ? context.tr('Операций не было', 'No transactions')
                      : '+${FinancialCalculator.formatCentsCompact(report.incomeCents, currency: currency)}  ·  −${FinancialCalculator.formatCentsCompact(report.expenseCents, currency: currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isEmpty ? colors.textMuted : colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Net Result (Right)
          if (!isEmpty) ...[
            Text(
              '${isProfit ? '+' : '−'}${FinancialCalculator.formatCentsCompact(report.netCents.abs(), currency: currency)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isProfit ? colors.income : colors.expense,
                fontFeatures: const [FontFeature.tabularFigures()],
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
    );
  }
}
