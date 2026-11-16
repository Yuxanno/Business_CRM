import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_tr.dart';
import '../models/transaction.dart';
import '../services/financial_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Groups transactions by category and renders a calm donut chart + clean breakdown list.
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

  @override
  void didUpdateWidget(covariant CategoryChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _touchedIndex = -1;
    }
  }

  // Calm, cohesive business palette without neon/jarring colors
  static const List<Color> _calmPalette = [
    Color(0xFF0F766E), // Deep Teal
    Color(0xFF3B82F6), // Calm Blue
    Color(0xFF64748B), // Slate
    Color(0xFF14B8A6), // Soft Teal
    Color(0xFFD97706), // Muted Amber
    Color(0xFF475569), // Charcoal Slate
    Color(0xFF0284C7), // Steel Blue
    Color(0xFF94A3B8), // Cool Grey
  ];

  List<_CategoryData> _buildData() {
    final filtered =
        widget.transactions.where((t) => t.type == widget.type).toList();
    if (filtered.isEmpty) return [];

    final Map<String, int> grouped = {};
    for (final tx in filtered) {
      final key = (tx.category == null || tx.category!.trim().isEmpty)
          ? 'other'
          : tx.category!;
      grouped[key] = (grouped[key] ?? 0) + tx.amountCents;
    }

    final total = grouped.values.fold<int>(0, (a, b) => a + b);
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.asMap().entries.map((e) {
      final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
      return _CategoryData(
        key: e.value.key,
        label: _labelFor(e.value.key),
        icon: _iconFor(e.value.key),
        amountCents: e.value.value,
        percentage: pct.toDouble(),
        color: _calmPalette[e.key % _calmPalette.length],
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Text(
            context.tr(
              'Нет операций в этой категории',
              'No transactions in this category',
            ),
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ),
      );
    }

    final totalCents = data.fold<int>(0, (s, d) => s + d.amountCents);
    final selectedItem =
        (_touchedIndex >= 0 && _touchedIndex < data.length)
            ? data[_touchedIndex]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Compact Donut Chart + Center Summary ───────────────────────────
        SizedBox(
          height: 184,
          child: RepaintBoundary(
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
                        radius: isTouched ? 44 : 38,
                        showTitle: false,
                      );
                    }).toList(),
                    centerSpaceRadius: 52,
                    sectionsSpace: 2.5,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          return;
                        }
                        final idx =
                            response!.touchedSection!.touchedSectionIndex;
                        if (idx >= 0 && idx < data.length && idx != _touchedIndex) {
                          HapticFeedback.selectionClick();
                          setState(() => _touchedIndex = idx);
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedItem != null
                            ? selectedItem.label
                            : (widget.type == TransactionType.income
                                ? context.tr('Все доходы', 'All income')
                                : context.tr('Все расходы', 'All expenses')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedItem != null
                            ? '${selectedItem.percentage.toStringAsFixed(0)}%'
                            : FinancialCalculator.formatCentsCompact(
                                totalCents,
                                currency: widget.currency,
                              ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Divider(height: 1, color: colors.divider),
        const SizedBox(height: 10),

        // ── Clean Category Breakdown Rows ──────────────────────────────────
        ...data.asMap().entries.map(
              (e) => _CategoryBreakdownRow(
                data: e.value,
                isSelected: e.key == _touchedIndex,
                currency: widget.currency,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(
                    () => _touchedIndex = _touchedIndex == e.key ? -1 : e.key,
                  );
                },
              ),
            ),
      ],
    );
  }

  String _labelFor(String cat) {
    if (TransactionCategories.customLabels.containsKey(cat)) {
      return TransactionCategories.customLabels[cat]!;
    }
    const labelsRu = {
      'order_payment': 'Оплата заказа',
      'service': 'Услуги',
      'sale': 'Продажи',
      'refund_received': 'Возврат средств',
      'other_income': 'Прочий доход',
      'supplies': 'Материалы и сырьё',
      'rent': 'Аренда',
      'utilities': 'Коммунальные услуги',
      'transport': 'Транспорт и логистика',
      'marketing': 'Реклама и маркетинг',
      'salary': 'Зарплата',
      'equipment': 'Оборудование',
      'taxes': 'Налоги и сборы',
      'other_expense': 'Прочий расход',
      'debt_received': 'Возврат долга',
      'debt_paid': 'Погашение долга',
      'other': 'Другое',
    };
    const labelsEn = {
      'order_payment': 'Order payment',
      'service': 'Services',
      'sale': 'Sales',
      'refund_received': 'Refunds',
      'other_income': 'Other income',
      'supplies': 'Supplies & materials',
      'rent': 'Rent',
      'utilities': 'Utilities',
      'transport': 'Transport & logistics',
      'marketing': 'Ads & marketing',
      'salary': 'Salaries',
      'equipment': 'Equipment',
      'taxes': 'Taxes & fees',
      'other_expense': 'Other expense',
      'debt_received': 'Debt repayment',
      'debt_paid': 'Debt payment',
      'other': 'Other',
    };
    final map = AppTr.isEn ? labelsEn : labelsRu;
    return map[cat] ?? cat;
  }

  IconData _iconFor(String cat) {
    return switch (cat) {
      'order_payment' => Icons.receipt_long_outlined,
      'service' => Icons.handyman_outlined,
      'sale' => Icons.shopping_bag_outlined,
      'refund_received' => Icons.replay_rounded,
      'supplies' => Icons.inventory_2_outlined,
      'rent' => Icons.storefront_outlined,
      'utilities' => Icons.bolt_outlined,
      'transport' => Icons.local_shipping_outlined,
      'marketing' => Icons.campaign_outlined,
      'salary' => Icons.badge_outlined,
      'equipment' => Icons.precision_manufacturing_outlined,
      'taxes' => Icons.account_balance_outlined,
      'debt_received' || 'debt_paid' => Icons.handshake_outlined,
      _ => Icons.category_outlined,
    };
  }
}

class _CategoryData {
  const _CategoryData({
    required this.key,
    required this.label,
    required this.icon,
    required this.amountCents,
    required this.percentage,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final int amountCents;
  final double percentage;
  final Color color;
}

class _CategoryBreakdownRow extends StatelessWidget {
  const _CategoryBreakdownRow({
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
    final progress = (data.percentage / 100.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          // Keep RGB channels constant when alpha=0 so AnimatedContainer never
          // interpolates through Colors.transparent (0x00000000 -> muddy grey).
          color: data.color.withValues(alpha: isSelected ? 0.08 : 0.0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: data.color.withValues(alpha: isSelected ? 0.42 : 0.0),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    data.icon,
                    size: 15,
                    color: data.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FinancialCalculator.formatCents(
                    data.amountCents,
                    currency: currency,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${data.percentage.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: colors.surfaceSecondary,
                  valueColor: AlwaysStoppedAnimation(data.color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
