import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_skeleton.dart';

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
      // Build list of (year, month) for last 12 months
      final months = List.generate(12, (i) {
        var month = now.month - i;
        var year = now.year;
        while (month < 1) {
          month += 12;
          year--;
        }
        return (year: year, month: month);
      });

      // Load all months in parallel
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

    // Best month for the year badge
    final bestMonth = _reports.isNotEmpty
        ? _reports.reduce((a, b) => a.netCents > b.netCents ? a : b)
        : null;
    final totalIncome =
        _reports.fold<int>(0, (s, r) => s + r.incomeCents);
    final totalExpense =
        _reports.fold<int>(0, (s, r) => s + r.expenseCents);
    final hasAnyData = totalIncome > 0 || totalExpense > 0;

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
                    onTap: () => context.go('/profile'),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 22, color: colors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Отчёты',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  // Refresh button
                  GestureDetector(
                    onTap: _loading ? null : _loadReports,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                      ),
                      child: _loading
                          ? Padding(
                              padding: const EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(Icons.refresh_rounded,
                              size: 18, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                      child: const AppSkeletonList(),
                    )
                  : _error != null
                      ? AppEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Ошибка загрузки',
                          subtitle: 'Проверьте подключение к серверу',
                          actionLabel: 'Повторить',
                          onAction: _loadReports,
                        )
                      : !hasAnyData
                          ? const AppEmptyState(
                              icon: Icons.insights_outlined,
                              title: 'Отчётов пока нет',
                              subtitle:
                                  'Когда появятся операции, здесь будет итог по месяцам',
                            )
                          : RefreshIndicator(
                              color: colors.primary,
                              onRefresh: _loadReports,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.xl,
                                    AppSpacing.xs,
                                    AppSpacing.xl,
                                    100),
                                itemCount: _reports.length +
                                    (hasAnyData ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  // Year summary banner at top
                                  if (hasAnyData && i == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AppSpacing.lg),
                                      child: _YearSummary(
                                        totalIncome: totalIncome,
                                        totalExpense: totalExpense,
                                        currency: currency,
                                        bestMonth: bestMonth,
                                      ),
                                    );
                                  }
                                  final report =
                                      _reports[hasAnyData ? i - 1 : i];
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    child: _MonthCard(
                                      report: report,
                                      currency: currency,
                                      isBest: bestMonth != null &&
                                          hasAnyData &&
                                          report.year == bestMonth.year &&
                                          report.month == bestMonth.month &&
                                          bestMonth.netCents > 0,
                                      onTap: () => context.go(
                                          '/profile/reports/${report.year}/${report.month}'),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

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

// ─── Year summary banner ──────────────────────────────────────────────────────

class _YearSummary extends StatelessWidget {
  const _YearSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.currency,
    required this.bestMonth,
  });

  final int totalIncome;
  final int totalExpense;
  final String currency;
  final _MonthReport? bestMonth;

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    final isProfit = net >= 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0F2027), const Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  'За 12 месяцев',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.80),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            FinancialCalculator.formatCents(net.abs(),
                currency: currency),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isProfit
                  ? const Color(0xFF34D399)
                  : const Color(0xFFFB7185),
              letterSpacing: -1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            isProfit ? 'Общая прибыль' : 'Общий убыток',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'Доходы',
                  value: FinancialCalculator.formatCentsCompact(
                      totalIncome, currency: currency),
                  color: const Color(0xFF34D399),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Расходы',
                  value: FinancialCalculator.formatCentsCompact(
                      totalExpense, currency: currency),
                  color: const Color(0xFFFB7185),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          if (bestMonth != null && bestMonth!.netCents > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(
                color: Colors.white.withValues(alpha: 0.10), height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 13,
                    color: const Color(0xFFFBBF24)),
                const SizedBox(width: 5),
                Text(
                  'Лучший месяц: ${DateHelper.formatMonthYear(DateTime(bestMonth!.year, bestMonth!.month))} · ${FinancialCalculator.formatCentsCompact(bestMonth!.netCents, currency: currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
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

// ─── Month card ───────────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.report,
    required this.currency,
    required this.isBest,
    required this.onTap,
  });

  final _MonthReport report;
  final String currency;
  final bool isBest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final netColor =
        report.isProfit ? colors.income : colors.expense;

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          // Month label + mini bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateHelper.formatMonthYear(
                          DateTime(report.year, report.month)),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: report.isEmpty
                            ? colors.textMuted
                            : colors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '★ лучший',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!report.isEmpty) ...[
                  const SizedBox(height: 5),
                  // Mini inline bar: income vs expense
                  _MiniBar(
                    incomeCents: report.incomeCents,
                    expenseCents: report.expenseCents,
                    currency: currency,
                  ),
                ] else ...[
                  const SizedBox(height: 3),
                  Text(
                    'Нет данных',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Net amount
          if (!report.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (report.isProfit ? '+' : '−') +
                      FinancialCalculator.formatCentsCompact(
                          report.netCents.abs(),
                          currency: currency),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: netColor,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  report.isProfit ? 'прибыль' : 'убыток',
                  style: TextStyle(
                      fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: colors.textMuted),
        ],
      ),
    );
  }
}

// ─── Mini income/expense bar ──────────────────────────────────────────────────

class _MiniBar extends StatelessWidget {
  const _MiniBar({
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

    return Row(
      children: [
        if (incomeCents > 0) ...[
          Icon(Icons.arrow_downward_rounded,
              size: 9, color: colors.income),
          const SizedBox(width: 2),
          Text(
            FinancialCalculator.formatCentsCompact(incomeCents,
                currency: currency),
            style:
                TextStyle(fontSize: 11, color: colors.income),
          ),
        ],
        if (incomeCents > 0 && expenseCents > 0)
          Text('  ·  ',
              style: TextStyle(
                  fontSize: 11, color: colors.textMuted)),
        if (expenseCents > 0) ...[
          Icon(Icons.arrow_upward_rounded,
              size: 9, color: colors.expense),
          const SizedBox(width: 2),
          Text(
            FinancialCalculator.formatCentsCompact(expenseCents,
                currency: currency),
            style: TextStyle(
                fontSize: 11, color: colors.expense),
          ),
        ],
      ],
    );
  }
}
