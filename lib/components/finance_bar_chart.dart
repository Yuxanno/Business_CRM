import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../services/financial_calculator.dart';

enum _ChartMode { bars, area }

/// Modern interactive chart showing daily income vs expense for a month.
/// Supports switching between grouped bars and smooth area curves,
/// with clean rounded Y-axis ticks and RepaintBoundary isolation.
class FinanceBarChart extends StatefulWidget {
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
  State<FinanceBarChart> createState() => _FinanceBarChartState();
}

class _FinanceBarChartState extends State<FinanceBarChart> {
  _ChartMode _mode = _ChartMode.bars;

  /// In wave mode: true = running total for the month, false = per-day values.
  bool _cumulative = true;

  /// Hold-only tooltip indices; cleared as soon as the pointer is released.
  int? _touchedLineSpotIndex;
  int? _touchedBarGroupIndex;
  int? _touchedBarRodIndex;
  bool _suppressChartLerp = false;

  static bool _isHoldEvent(FlTouchEvent event) =>
      event is FlTapDownEvent ||
      event is FlPanDownEvent ||
      event is FlPanStartEvent ||
      event is FlPanUpdateEvent ||
      event is FlLongPressStart ||
      event is FlLongPressMoveUpdate;

  static bool _isReleaseEvent(FlTouchEvent event) =>
      event is FlTapUpEvent ||
      event is FlTapCancelEvent ||
      event is FlPanEndEvent ||
      event is FlPanCancelEvent ||
      event is FlLongPressEnd ||
      event is FlPointerExitEvent;

  void _clearTouchedState() {
    _touchedLineSpotIndex = null;
    _touchedBarGroupIndex = null;
    _touchedBarRodIndex = null;
  }

  void _onPointerRelease() {
    if (_touchedLineSpotIndex != null ||
        _touchedBarGroupIndex != null ||
        _touchedBarRodIndex != null) {
      setState(() {
        _clearTouchedState();
        _suppressChartLerp = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant FinanceBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.dailyData != widget.dailyData ||
        oldWidget.currency != widget.currency) {
      _clearTouchedState();
      _suppressChartLerp = false;
    }
  }

  static const _shortMonths = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  static const _shortMonthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats cents into a short axis label without currency code (e.g. 2M, 500K).
  String _formatAxisCents(double cents) {
    final value = cents / 100.0;
    if (value <= 0) return '0';
    if (value >= 1000000) {
      final m = value / 1000000;
      return m == m.roundToDouble()
          ? '${m.toInt()}M'
          : '${m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}K'
          : '${k.toStringAsFixed(0)}K';
    }
    return value.toInt().toString();
  }

  /// Computes a clean rounded ceiling for the Y axis so grid lines have neat labels.
  double _computeNiceMaxY(double rawMax) {
    if (rawMax <= 0) return 10000; // 100 units in cents
    final units = rawMax / 100.0;
    final magnitude =
        math.pow(10, (math.log(units) / math.ln10).floor()).toDouble();
    final normalized = units / magnitude; // 1.0 .. 9.99

    double niceNormalized;
    if (normalized <= 1.2) {
      niceNormalized = 1.2;
    } else if (normalized <= 1.5) {
      niceNormalized = 1.6;
    } else if (normalized <= 2.0) {
      niceNormalized = 2.0;
    } else if (normalized <= 2.5) {
      niceNormalized = 2.5;
    } else if (normalized <= 3.0) {
      niceNormalized = 3.2;
    } else if (normalized <= 4.0) {
      niceNormalized = 4.0;
    } else if (normalized <= 5.0) {
      niceNormalized = 5.0;
    } else if (normalized <= 6.0) {
      niceNormalized = 6.0;
    } else if (normalized <= 8.0) {
      niceNormalized = 8.0;
    } else {
      niceNormalized = 10.0;
    }
    return niceNormalized * magnitude * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final daysInMonth = DateUtils.getDaysInMonth(widget.year, widget.month);
    final monthShort = (context.isEn ? _shortMonthsEn : _shortMonths)[
        (widget.month - 1).clamp(0, 11)];

    // Build per-day maps
    final Map<int, int> incomeByDay = {};
    final Map<int, int> expenseByDay = {};
    int peakDay = 1;
    int peakAmount = 0;

    for (final row in widget.dailyData) {
      final dayStr = row['day'] as String;
      final parts = dayStr.split('-');
      if (parts.length < 3) continue;
      final day = int.tryParse(parts[2]) ?? 1;
      final total = (row['total'] as num?)?.toInt() ?? 0;
      if (row['type'] == 'income') {
        incomeByDay[day] = (incomeByDay[day] ?? 0) + total;
      } else {
        expenseByDay[day] = (expenseByDay[day] ?? 0) + total;
      }
    }

    final activeDays = <int>{...incomeByDay.keys, ...expenseByDay.keys}.toList()
      ..sort();

    if (activeDays.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats_rounded,
                  size: 28, color: colors.textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('Нет данных за этот период', 'No data for this period'),
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    for (final d in activeDays) {
      final dayVolume = (incomeByDay[d] ?? 0) + (expenseByDay[d] ?? 0);
      if (dayVolume > peakAmount) {
        peakAmount = dayVolume;
        peakDay = d;
      }
    }

    final allValues = [
      ...incomeByDay.values,
      ...expenseByDay.values,
    ];
    final rawMax = allValues.isEmpty
        ? 10000.0
        : allValues.reduce(math.max).toDouble();
    final maxY = _computeNiceMaxY(rawMax);
    final interval = maxY / 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row: Legend + Chart Mode Switcher
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LegendDot(
                      color: colors.income,
                      label: context.tr('Доходы', 'Income')),
                  _LegendDot(
                      color: colors.expense,
                      label: context.tr('Расходы', 'Expenses')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Sliding pill mode toggle (Дни | Волна)
            SizedBox(
              width: 136,
              height: 32,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: colors.border.withValues(alpha: 0.6)),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: _mode == _ChartMode.bars
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeTab(
                            icon: Icons.bar_chart_rounded,
                            label: context.tr('Дни', 'Bars'),
                            selected: _mode == _ChartMode.bars,
                            transparentPill: true,
                            onTap: () {
                              if (_mode != _ChartMode.bars) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _mode = _ChartMode.bars;
                                  _clearTouchedState();
                                  _suppressChartLerp = false;
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _ModeTab(
                            icon: Icons.show_chart_rounded,
                            label: context.tr('Волна', 'Wave'),
                            selected: _mode == _ChartMode.area,
                            transparentPill: true,
                            onTap: () {
                              if (_mode != _ChartMode.area) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _mode = _ChartMode.area;
                                  _clearTouchedState();
                                  _suppressChartLerp = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _mode == _ChartMode.area
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      _ModeTab(
                        icon: Icons.trending_up_rounded,
                        label: context.tr('Нарастающим итогом', 'Cumulative'),
                        selected: _cumulative,
                        onTap: () {
                          if (!_cumulative) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _cumulative = true;
                              _clearTouchedState();
                              _suppressChartLerp = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _ModeTab(
                        icon: Icons.calendar_view_day_rounded,
                        label: context.tr('По дням', 'Daily'),
                        selected: !_cumulative,
                        onTap: () {
                          if (_cumulative) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _cumulative = false;
                              _clearTouchedState();
                              _suppressChartLerp = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: AppSpacing.md),

        // Chart body isolated in RepaintBoundary for 60/120fps scrolling
        RepaintBoundary(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (_) => _onPointerRelease(),
            onPointerCancel: (_) => _onPointerRelease(),
            child: SizedBox(
              height: 185,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _mode == _ChartMode.bars
                    ? _buildBarChart(
                        colors: colors,
                        daysInMonth: daysInMonth,
                        incomeByDay: incomeByDay,
                        expenseByDay: expenseByDay,
                        activeDays: activeDays,
                        maxY: maxY,
                        interval: interval,
                        monthShort: monthShort,
                      )
                    : _buildAreaChart(
                        colors: colors,
                        daysInMonth: daysInMonth,
                        incomeByDay: incomeByDay,
                        expenseByDay: expenseByDay,
                        maxY: maxY,
                        interval: interval,
                        monthShort: monthShort,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Subtle bottom insight strip
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 15, color: colors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.tr(
                    'Активных дней: ${activeDays.length}',
                    'Active days: ${activeDays.length}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.tr(
                    'Пик активности: $peakDay $monthShort',
                    'Peak day: $monthShort $peakDay',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart({
    required AppSemanticColors colors,
    required int daysInMonth,
    required Map<int, int> incomeByDay,
    required Map<int, int> expenseByDay,
    required List<int> activeDays,
    required double maxY,
    required double interval,
    required String monthShort,
  }) {
    // If there are only a few active days, show a 7-day window around them
    // so bars look well-proportioned and contextualized instead of floating alone.
    List<int> visibleDays;
    if (activeDays.length <= 7) {
      final minD = activeDays.first;
      final maxD = activeDays.last;
      if (maxD - minD < 6) {
        final start = math.max(1, minD - ((6 - (maxD - minD)) ~/ 2));
        final end = math.min(daysInMonth, start + 6);
        final adjustedStart = math.max(1, end - 6);
        visibleDays =
            List.generate(end - adjustedStart + 1, (i) => adjustedStart + i);
      } else {
        visibleDays = activeDays;
      }
    } else {
      visibleDays = activeDays;
    }

    final rodWidth = visibleDays.length <= 7
        ? 10.0
        : visibleDays.length <= 14
            ? 7.0
            : 5.0;

    final barGroups = visibleDays.asMap().entries.map((entry) {
      final groupIndex = entry.key;
      final d = entry.value;
      final inc = (incomeByDay[d] ?? 0).toDouble();
      final exp = (expenseByDay[d] ?? 0).toDouble();
      final hasActivity = inc > 0 || exp > 0;
      final showRodTooltip = hasActivity &&
          _touchedBarGroupIndex == groupIndex &&
          _touchedBarRodIndex != null;

      return BarChartGroupData(
        x: d,
        barsSpace: 3,
        showingTooltipIndicators:
            showRodTooltip ? [_touchedBarRodIndex!] : const [],
        barRods: hasActivity
            ? [
                BarChartRodData(
                  toY: inc > 0 ? inc : maxY * 0.015,
                  color: inc > 0
                      ? colors.income
                      : colors.border.withValues(alpha: 0.35),
                  width: rodWidth,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: colors.surfaceSecondary.withValues(alpha: 0.45),
                  ),
                ),
                BarChartRodData(
                  toY: exp > 0 ? exp : maxY * 0.015,
                  color: exp > 0
                      ? colors.expense
                      : colors.border.withValues(alpha: 0.35),
                  width: rodWidth,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: colors.surfaceSecondary.withValues(alpha: 0.45),
                  ),
                ),
              ]
            : [
                BarChartRodData(
                  toY: maxY * 0.025,
                  color: colors.border.withValues(alpha: 0.5),
                  width: rodWidth,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: colors.surfaceSecondary.withValues(alpha: 0.35),
                  ),
                ),
              ],
      );
    }).toList();

    return BarChart(
      key: const ValueKey('bars'),
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.divider,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildTitlesData(
          colors: colors,
          interval: interval,
          visibleDays: visibleDays,
          daysInMonth: daysInMonth,
          monthShort: monthShort,
        ),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (_isReleaseEvent(event)) {
              _onPointerRelease();
              return;
            }
            if (!_isHoldEvent(event)) return;
            final spot = response?.spot;
            final nextGroup = spot?.touchedBarGroupIndex;
            final nextRod = spot?.touchedRodDataIndex;
            if (nextGroup != _touchedBarGroupIndex ||
                nextRod != _touchedBarRodIndex) {
              setState(() {
                _touchedBarGroupIndex = nextGroup;
                _touchedBarRodIndex = nextRod;
                _suppressChartLerp = true;
              });
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink.withValues(alpha: 0.92),
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = group.x;
              final inc = incomeByDay[day] ?? 0;
              final exp = expenseByDay[day] ?? 0;
              if (inc == 0 && exp == 0) return null;
              if (rodIndex == 1 && inc > 0) {
                // Show combined tooltip on first rod or active rod
              }
              final isIncomeRod = rodIndex == 0;
              final valueCents = isIncomeRod ? inc : exp;
              if (valueCents == 0) return null;
              final sign = isIncomeRod ? '+' : '−';
              return BarTooltipItem(
                '$day $monthShort\n',
                const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                children: [
                  TextSpan(
                    text:
                        '$sign${FinancialCalculator.formatCents(valueCents, currency: widget.currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isIncomeRod
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFB7185),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      duration:
          _suppressChartLerp ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAreaChart({
    required AppSemanticColors colors,
    required int daysInMonth,
    required Map<int, int> incomeByDay,
    required Map<int, int> expenseByDay,
    required double maxY,
    required double interval,
    required String monthShort,
  }) {
    final now = DateTime.now();
    final isCurrentMonth =
        widget.year == now.year && widget.month == now.month;
    final isFutureMonth = widget.year > now.year ||
        (widget.year == now.year && widget.month > now.month);
    final maxActiveDay = activeDaysForMap(incomeByDay, expenseByDay);
    final endDay = isFutureMonth
        ? maxActiveDay
        : isCurrentMonth
            ? math.min(daysInMonth, math.max(now.day, maxActiveDay))
            : daysInMonth;

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    var runIncome = 0.0;
    var runExpense = 0.0;
    var peak = 0.0;

    for (int d = 1; d <= endDay; d++) {
      final inc = (incomeByDay[d] ?? 0).toDouble();
      final exp = (expenseByDay[d] ?? 0).toDouble();
      runIncome += inc;
      runExpense += exp;
      final yi = _cumulative ? runIncome : inc;
      final ye = _cumulative ? runExpense : exp;
      incomeSpots.add(FlSpot(d.toDouble(), yi));
      expenseSpots.add(FlSpot(d.toDouble(), ye));
      peak = math.max(peak, math.max(yi, ye));
    }
    // Own scale: running totals are much larger than single-day values.
    maxY = _computeNiceMaxY(peak);
    interval = maxY / 4.0;

    final touchedIdx = (_touchedLineSpotIndex != null &&
            _touchedLineSpotIndex! >= 0 &&
            _touchedLineSpotIndex! < incomeSpots.length &&
            _touchedLineSpotIndex! < expenseSpots.length)
        ? _touchedLineSpotIndex
        : null;
    final showingSpotList = touchedIdx != null ? [touchedIdx] : const <int>[];

    final incomeBar = LineChartBarData(
      spots: incomeSpots,
      showingIndicators: showingSpotList,
      isCurved: true,
      curveSmoothness: 0.35,
      preventCurveOverShooting: true,
      color: colors.income,
      barWidth: 3.0,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            colors.income.withValues(alpha: 0.22),
            colors.income.withValues(alpha: 0.04),
            colors.income.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );

    final expenseBar = LineChartBarData(
      spots: expenseSpots,
      showingIndicators: showingSpotList,
      isCurved: true,
      curveSmoothness: 0.35,
      preventCurveOverShooting: true,
      color: colors.expense,
      barWidth: 2.2,
      dashArray: const [6, 4],
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    return LineChart(
      key: const ValueKey('area'),
      LineChartData(
        minX: 1,
        maxX: daysInMonth.toDouble(),
        minY: 0,
        maxY: maxY,
        extraLinesData: isCurrentMonth && endDay < daysInMonth
            ? ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: endDay.toDouble(),
                    color: colors.textMuted.withValues(alpha: 0.35),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              )
            : const ExtraLinesData(),
        showingTooltipIndicators: touchedIdx != null
            ? [
                ShowingTooltipIndicators([
                  LineBarSpot(incomeBar, 0, incomeSpots[touchedIdx]),
                  LineBarSpot(expenseBar, 1, expenseSpots[touchedIdx]),
                ]),
              ]
            : const [],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.divider,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _formatAxisCents(value),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final d = value.toInt();
                if (d != 1 &&
                    d != 7 &&
                    d != 14 &&
                    d != 21 &&
                    d != daysInMonth) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [incomeBar, expenseBar],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchSpotThreshold: 40,
          touchCallback: (event, response) {
            if (_isReleaseEvent(event)) {
              _onPointerRelease();
              return;
            }
            if (!_isHoldEvent(event)) return;
            final spots = response?.lineBarSpots;
            final nextIdx =
                (spots != null && spots.isNotEmpty) ? spots.first.spotIndex : null;
            if (nextIdx != _touchedLineSpotIndex) {
              setState(() {
                _touchedLineSpotIndex = nextIdx;
                _suppressChartLerp = true;
              });
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
              .map((_) => TouchedSpotIndicatorData(
                    FlLine(
                      color: colors.textMuted.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: bar.color ?? colors.primary,
                        strokeWidth: 2,
                        strokeColor: colors.surface,
                      ),
                    ),
                  ))
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink.withValues(alpha: 0.94),
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              // One combined tooltip per day (on the first touched line).
              return [
                for (var i = 0; i < touchedSpots.length; i++)
                  if (i > 0)
                    null
                  else
                    () {
                      final day = touchedSpots.first.x.toInt();
                      final inc = incomeByDay[day] ?? 0;
                      final exp = expenseByDay[day] ?? 0;
                      String fmt(int v) => FinancialCalculator.formatCents(v,
                          currency: widget.currency);
                      return LineTooltipItem(
                        '$day $monthShort\n',
                        const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                        children: [
                          TextSpan(
                            text: '+${fmt(inc)}\n',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          TextSpan(
                            text: '−${fmt(exp)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFB7185),
                            ),
                          ),
                        ],
                      );
                    }(),
              ];
            },
          ),
        ),
      ),
      duration:
          _suppressChartLerp ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  int activeDaysForMap(Map<int, int> inc, Map<int, int> exp) {
    int maxD = 0;
    for (final k in inc.keys) {
      if (k > maxD) maxD = k;
    }
    for (final k in exp.keys) {
      if (k > maxD) maxD = k;
    }
    return maxD;
  }

  FlTitlesData _buildTitlesData({
    required AppSemanticColors colors,
    required double interval,
    required List<int> visibleDays,
    required int daysInMonth,
    required String monthShort,
  }) {
    final step = visibleDays.length <= 8
        ? 1
        : visibleDays.length <= 16
            ? 2
            : 4;

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value <= 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _formatAxisCents(value),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          getTitlesWidget: (value, meta) {
            final day = value.toInt();
            final idx = visibleDays.indexOf(day);
            if (idx == -1) return const SizedBox.shrink();
            if (idx % step != 0 && idx != visibleDays.length - 1) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                visibleDays.length <= 7 ? '$day $monthShort' : '$day',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.transparentPill = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool transparentPill;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (!transparentPill && selected)
              ? colors.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: (!transparentPill && selected)
              ? [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? colors.primary : colors.textMuted,
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.textPrimary : colors.textMuted,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
