import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Load last 12 months
  final List<_MonthReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final provider = context.read<FinanceProvider>();
    final now = DateTime.now();
    final reports = <_MonthReport>[];

    for (int i = 0; i < 12; i++) {
      var month = now.month - i;
      var year = now.year;
      while (month < 1) {
        month += 12;
        year--;
      }

      // Temporarily load each month to get totals
      await provider.loadMonth(year, month);
      reports.add(_MonthReport(
        year: year,
        month: month,
        incomeCents: provider.incomeCents,
        expenseCents: provider.expenseCents,
      ));
    }

    // Restore current month
    await provider.loadMonth(now.year, now.month);

    if (mounted) {
      setState(() {
        _reports.addAll(reports);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Отчёты')),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _reports.isEmpty
              ? Center(
                  child: Text('Нет данных',
                      style: TextStyle(color: colors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 80),
                  itemCount: _reports.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _MonthReportCard(
                    report: _reports[i],
                    currency: currency,
                    onTap: () => context.go(
                        '/profile/reports/${_reports[i].year}/${_reports[i].month}'),
                  ),
                ),
    );
  }
}

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
}

class _MonthReportCard extends StatelessWidget {
  const _MonthReportCard({
    required this.report,
    required this.currency,
    required this.onTap,
  });

  final _MonthReport report;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateHelper.formatMonthYear(
                    DateTime(report.year, report.month)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _MiniStat(
                    label: '+',
                    value: FinancialCalculator.formatCentsCompact(
                        report.incomeCents, currency: currency),
                    color: colors.income,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _MiniStat(
                    label: '-',
                    value: FinancialCalculator.formatCentsCompact(
                        report.expenseCents, currency: currency),
                    color: colors.expense,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FinancialCalculator.formatCents(report.netCents.abs(),
                    currency: currency),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: report.isProfit ? colors.income : colors.expense,
                ),
              ),
              Text(
                report.isProfit ? 'Прибыль' : 'Убыток',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: colors.textMuted),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(value,
            style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
