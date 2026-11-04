import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../services/financial_calculator.dart';

/// Bar chart showing daily income vs expense for a month.
/// [dailyData] from TransactionRepository.getDailyTotals() —
/// each map has: {day: 'YYYY-MM-DD', type: 'income'|'expense', total: int}
class FinanceBarChart extends StatelessWidget {
  const FinanceBarChart({
    super.key,
    required this.dailyData,
    required this.year,
    required this.month,
    required this.currency,
  });

  final List<Map<String, dynamic>> dailyData;
  final int year;
  final int month;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // Build per-day maps
    final Map<int, int> incomeByDay = {};
    final Map<int, int> expenseByDay = {};
    for (final row in dailyData) {
      final dayStr = row['day'] as String; // 'YYYY-MM-DD'
      final day = int.parse(dayStr.split('-')[2]);
      final total = (row['total'] as int?) ?? 0;
      if (row['type'] == 'income') {
        incomeByDay[day] = (incomeByDay[day] ?? 0) + total;
      } else {
        expenseByDay[day] = (expenseByDay[day] ?? 0) + total;
      }
    }

    if (incomeByDay.isEmpty && expenseByDay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Нет данных за этот период',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ),
      );
    }

    // Max value for Y axis
    final allValues = [
      ...incomeByDay.values,
      ...expenseByDay.values,
    ];
    final maxVal =
        allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b).toDouble();

    // Show every 5th day label, group days into weeks for readability
    final barGroups = <BarChartGroupData>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final inc = (incomeByDay[d] ?? 0).toDouble();
      final exp = (expenseByDay[d] ?? 0).toDouble();
      if (inc > 0 || exp > 0) {
        barGroups.add(
          BarChartGroupData(
            x: d,
            barRods: [
              if (inc > 0)
                BarChartRodData(
                  toY: inc,
                  color: colors.income,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              if (exp > 0)
                BarChartRodData(
                  toY: exp,
                  color: colors.expense,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
            ],
            barsSpace: 2,
          ),
        );
      }
    }

    if (barGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Нет данных за этот период',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: colors.income, label: 'Доходы'),
            const SizedBox(width: AppSpacing.xl),
            _LegendDot(color: colors.expense, label: 'Расходы'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              minY: 0,
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colors.divider,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: maxVal / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        FinancialCalculator.formatCentsCompact(
                            value.toInt(),
                            currency: currency),
                        style: TextStyle(
                            fontSize: 9, color: colors.textMuted),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt();
                      if (day % 7 != 1 && day != daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$day',
                          style: TextStyle(
                              fontSize: 10, color: colors.textMuted),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colors.surface,
                  tooltipBorder: BorderSide(color: colors.border),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isIncome = rod.color == colors.income;
                    return BarTooltipItem(
                      '${isIncome ? '+' : '-'}${FinancialCalculator.formatCents(rod.toY.toInt(), currency: currency)}',
                      TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isIncome ? colors.income : colors.expense,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}
