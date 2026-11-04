import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/financial_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Groups transactions by category and renders a pie chart + legend.
class CategoryChartWidget extends StatefulWidget {
  const CategoryChartWidget({
    super.key,
    required this.transactions,
    required this.type,
    required this.currency,
  });

  final List<AppTransaction> transactions;
  final TransactionType type;
  final String currency;

  @override
  State<CategoryChartWidget> createState() => _CategoryChartWidgetState();
}

class _CategoryChartWidgetState extends State<CategoryChartWidget> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];

  List<_CategoryData> _buildData() {
    final filtered =
        widget.transactions.where((t) => t.type == widget.type).toList();
    if (filtered.isEmpty) return [];

    final Map<String, int> grouped = {};
    for (final tx in filtered) {
      final key = tx.category ?? 'other';
      grouped[key] = (grouped[key] ?? 0) + tx.amountCents;
    }

    final total = grouped.values.fold<int>(0, (a, b) => a + b);
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.asMap().entries.map((e) {
      final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
      return _CategoryData(
        label: _labelFor(e.value.key),
        amountCents: e.value.value,
        percentage: pct.toDouble(),
        color: _palette[e.key % _palette.length],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildData();
    final colors = context.appColors;

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Нет данных по категориям',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: data.asMap().entries.map((e) {
                    final isTouched = e.key == _touchedIndex;
                    return PieChartSectionData(
                      color: e.value.color,
                      value: e.value.amountCents.toDouble(),
                      radius: isTouched ? 60 : 52,
                      showTitle: false,
                      badgeWidget: null,
                    );
                  }).toList(),
                  centerSpaceRadius: 56,
                  sectionsSpace: 3,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedIndex = -1;
                        } else {
                          _touchedIndex = response!
                              .touchedSection!.touchedSectionIndex;
                        }
                      });
                    },
                  ),
                ),
              ),
              // Center label
              if (_touchedIndex >= 0 && _touchedIndex < data.length)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data[_touchedIndex].label,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${data[_touchedIndex].percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.type == TransactionType.income
                          ? 'Доходы'
                          : 'Расходы',
                      style: TextStyle(
                          fontSize: 11, color: colors.textSecondary),
                    ),
                    Text(
                      '${data.length} кат.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Legend list
        ...data.asMap().entries.map((e) => _LegendItem(
              data: e.value,
              isSelected: e.key == _touchedIndex,
              currency: widget.currency,
              onTap: () => setState(
                  () => _touchedIndex = _touchedIndex == e.key ? -1 : e.key),
            )),
      ],
    );
  }

  String _labelFor(String cat) {
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
      'other': 'Другое',
    };
    return labels[cat] ?? cat;
  }
}

class _CategoryData {
  const _CategoryData({
    required this.label,
    required this.amountCents,
    required this.percentage,
    required this.color,
  });

  final String label;
  final int amountCents;
  final double percentage;
  final Color color;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.data,
    required this.isSelected,
    required this.currency,
    required this.onTap,
  });

  final _CategoryData data;
  final bool isSelected;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? data.color.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: data.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                data.label,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FinancialCalculator.formatCentsCompact(data.amountCents,
                      currency: currency),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '${data.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
