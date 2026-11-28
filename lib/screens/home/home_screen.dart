import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/notification_service.dart';
import '../../services/update_service.dart';
import '../../components/notifications_sheet.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/transaction.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../services/bootstrap_service.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/finance_bar_chart.dart';
import '../../components/app_skeleton.dart';

const double _kHomePadding = 20.0;

enum _ActivityFilter { all, income, expense }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// GlobalKey attached to the top-left 44x44 square avatar in the Home header.
  static final GlobalKey avatarKey = GlobalKey(debugLabel: 'homeAvatarKey');

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  bool _hideBalances = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeAndPrefetch();
    });
  }

  Future<void> _loadHomeAndPrefetch() async {
    if (!mounted) return;
    // Hydrates cache in parallel and runs a single batched /api/bootstrap request
    await BootstrapService.loadAll(context);
    if (mounted) {
      await NotificationService.instance.promptPermissionIfNeeded(context);
    }
    if (mounted) {
      unawaited(UpdateService.instance.checkAndPromptIfNeeded(context));
    }
  }

  Future<void> _pushAndReload(String route) async {
    HapticFeedback.lightImpact();
    await context.push(route);
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          backgroundColor: colors.surface,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await context.read<DashboardProvider>().reload();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Modern Header ──────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _kHomePadding,
                    AppSpacing.md,
                    _kHomePadding,
                    0,
                  ),
                  child: _Header(),
                ),
              ),

              // ── 2. Hero Financial Bento Card ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kHomePadding,
                    AppSpacing.md,
                    _kHomePadding,
                    0,
                  ),
                  child: RepaintBoundary(
                    child: _HeroFinancialCard(
                      hideBalances: _hideBalances,
                      onTogglePrivacy: () {
                        HapticFeedback.selectionClick();
                        setState(() => _hideBalances = !_hideBalances);
                      },
                    ),
                  ),
                ),
              ),

              // ── 3. Quick Actions Dock ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kHomePadding,
                    AppSpacing.md,
                    _kHomePadding,
                    0,
                  ),
                  child: _QuickActionsDock(onAction: _pushAndReload),
                ),
              ),

              // ── 4. Bento Business Overview ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kHomePadding,
                    AppSpacing.lg,
                    _kHomePadding,
                    0,
                  ),
                  child: _BentoStatsSection(
                    hideBalances: _hideBalances,
                  ),
                ),
              ),

              // ── 5. Month Dynamics Chart ───────────────────────────────────
              const SliverToBoxAdapter(
                child: _MonthDynamicsChartSection(),
              ),

              // ── 6. Recent Activity Section Header & Filter ────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kHomePadding,
                    AppSpacing.lg,
                    _kHomePadding,
                    AppSpacing.sm,
                  ),
                  child: _RecentActivityHeader(
                    selectedFilter: _activityFilter,
                    onFilterChanged: (filter) {
                      HapticFeedback.selectionClick();
                      setState(() => _activityFilter = filter);
                    },
                  ),
                ),
              ),

              // ── 7. Activity List Body ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _RecentActivityBody(
                  activityFilter: _activityFilter,
                  hideBalances: _hideBalances,
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxxl + 40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Month Dynamics Chart Section (Selector-isolated) ─────────────────────────

class _MonthDynamicsChartSection extends StatelessWidget {
  const _MonthDynamicsChartSection();

  @override
  Widget build(BuildContext context) {
    final chartData = context.select<DashboardProvider, List<Map<String, dynamic>>>(
      (d) => d.chartData,
    );
    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final year = context.select<DashboardProvider, int>((d) => d.year);
    final month = context.select<DashboardProvider, int>((d) => d.month);
    final currency = context.select<SettingsProvider, String>((s) => s.currency);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kHomePadding,
        AppSpacing.lg,
        _kHomePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: context.tr('Динамика месяца', 'Monthly dynamics'),
            subtitle: context.tr(
              'Поток средств по дням',
              'Daily cash flow',
            ),
            actionLabel: context.tr('Отчёт', 'Report'),
            actionIcon: Icons.analytics_outlined,
            onAction: () => context.go(
              '/profile/reports/$year/$month',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RepaintBoundary(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.cardLarge,
              child: FinanceBarChart(
                dailyData: chartData,
                year: year,
                month: month,
                currency: currency,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity Header & Body (Selector-isolated, zero AnimatedSwitcher) ─

class _RecentActivityHeader extends StatelessWidget {
  const _RecentActivityHeader({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final _ActivityFilter selectedFilter;
  final ValueChanged<_ActivityFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final recentActivity =
        context.select<DashboardProvider, List<AppTransaction>>(
      (d) => d.recentActivity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.tr(
            'Последние операции',
            'Recent transactions',
          ),
          actionLabel: context.tr('Все', 'All'),
          onAction: () => context.go('/finance'),
        ),
        if (recentActivity.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ActivityFilterBar(
            selected: selectedFilter,
            allCount: recentActivity.length,
            incomeCount: recentActivity
                .where((t) => t.type == TransactionType.income)
                .length,
            expenseCount: recentActivity
                .where((t) => t.type == TransactionType.expense)
                .length,
            onChanged: onFilterChanged,
          ),
        ],
      ],
    );
  }
}

class _RecentActivityBody extends StatelessWidget {
  const _RecentActivityBody({
    required this.activityFilter,
    required this.hideBalances,
  });

  final _ActivityFilter activityFilter;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLoading = context.select<DashboardProvider, bool>(
      (d) => d.isLoading || (!d.hasData && !d.hasLoadedOnce),
    );
    final recentActivity =
        context.select<DashboardProvider, List<AppTransaction>>(
      (d) => d.recentActivity,
    );
    final currency =
        context.select<SettingsProvider, String>((s) => s.currency);

    if (isLoading && recentActivity.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: _kHomePadding),
        child: AppSkeletonList(count: 3),
      );
    }

    if (recentActivity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kHomePadding),
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: context.tr(
            'За этот месяц операций нет',
            'No transactions this month',
          ),
          subtitle: context.tr(
            'Добавьте первый доход или расход с помощью быстрых кнопок выше',
            'Add your first income or expense using the quick actions above',
          ),
          actionLabel: context.tr(
            'Открыть Деньги',
            'Open Finance',
          ),
          onAction: () => context.go('/finance'),
        ),
      );
    }

    final filteredActivity = switch (activityFilter) {
      _ActivityFilter.all => recentActivity,
      _ActivityFilter.income => recentActivity
          .where((t) => t.type == TransactionType.income)
          .toList(),
      _ActivityFilter.expense => recentActivity
          .where((t) => t.type == TransactionType.expense)
          .toList(),
    };

    if (filteredActivity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kHomePadding,
          vertical: AppSpacing.lg,
        ),
        child: AppCard(
          radius: AppRadius.cardLarge,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                activityFilter == _ActivityFilter.income
                    ? context.tr(
                        'Нет операций дохода в списке последних',
                        'No income transactions in recent activity',
                      )
                    : context.tr(
                        'Нет операций расхода в списке последних',
                        'No expense transactions in recent activity',
                      ),
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kHomePadding),
      child: RepaintBoundary(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: AppRadius.cardLarge,
          child: Column(
            children: [
              for (int i = 0; i < filteredActivity.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: AppSpacing.md,
                    color: colors.divider.withValues(alpha: 0.7),
                  ),
                _ActivityTile(
                  tx: filteredActivity[i],
                  currency: currency,
                  hideBalances: hideBalances,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Lightweight Tactile Scale Wrapper ────────────────────────────────────────

class _ScaleTap extends StatefulWidget {
  const _ScaleTap({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ─── Zero-Overhead Money Text (no per-frame Ticker) ───────────────────────────

class _AnimatedMoneyText extends StatelessWidget {
  const _AnimatedMoneyText({
    required this.cents,
    required this.currency,
    required this.style,
    this.prefix = '',
    this.hide = false,
  });

  final int cents;
  final String currency;
  final TextStyle style;
  final String prefix;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    if (hide) {
      return Text('•••••• $currency', style: style);
    }

    final formatted = FinancialCalculator.formatCents(
      cents,
      currency: currency,
    );
    return Text('$prefix$formatted', style: style);
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null && actionLabel != null)
          _ScaleTap(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIcon != null) ...[
                    Icon(actionIcon, size: 13, color: colors.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  IconData _greetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 18) return Icons.light_mode_rounded;
    return Icons.nights_stay_rounded;
  }

  void _shiftMonth(BuildContext context, int year, int month, int delta) {
    HapticFeedback.selectionClick();
    var m = month + delta;
    var y = year;
    if (m > 12) {
      m = 1;
      y++;
    } else if (m < 1) {
      m = 12;
      y--;
    }
    context.read<DashboardProvider>().setMonth(y, m);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final businessName = context.select<SettingsProvider, String>(
      (s) => s.settings.businessName,
    );
    final ownerName = context.select<SettingsProvider, String>(
      (s) => s.settings.ownerName,
    );
    final name = businessName.isNotEmpty
        ? businessName
        : ownerName.isNotEmpty
            ? ownerName
            : context.tr('Мой бизнес', 'My business');

    final year = context.select<DashboardProvider, int>((d) => d.year);
    final month = context.select<DashboardProvider, int>((d) => d.month);
    final isRefreshing =
        context.select<DashboardProvider, bool>((d) => d.isRefreshing);
    final selectedDate = DateTime(year, month);

    return Row(
      children: [
        // Profile / Business Identity
        Expanded(
          child: _ScaleTap(
            onTap: () => context.go('/profile'),
            child: Row(
              children: [
                Container(
                  key: HomeScreen.avatarKey,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'B',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _greetingIcon(),
                            size: 12,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              DateHelper.greeting(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Notifications Bell Button with Unread Badge
        ValueListenableBuilder<List<AppNotification>>(
          valueListenable: NotificationService.instance.itemsNotifier,
          builder: (context, items, _) {
            final unread = items.where((n) => !n.isRead).length;
            return _ScaleTap(
              onTap: () {
                HapticFeedback.selectionClick();
                showNotificationsSheet(context);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      unread > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      size: 19,
                      color: unread > 0 ? colors.primary : colors.textSecondary,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 6),

        // Interactive Month Stepper + Picker Pill
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _shiftMonth(context, year, month, -1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 17,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickMonth(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isRefreshing
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Icon(
                              Icons.calendar_month_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        DateHelper.formatMonthYear(selectedDate),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _shiftMonth(context, year, month, 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    HapticFeedback.selectionClick();
    final dashboard = context.read<DashboardProvider>();
    var selectedYear = dashboard.year;
    final months = context.isEn
        ? const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ]
        : const [
            'Январь',
            'Февраль',
            'Март',
            'Апрель',
            'Май',
            'Июнь',
            'Июль',
            'Август',
            'Сентябрь',
            'Октябрь',
            'Ноябрь',
            'Декабрь',
          ];
    final colors = context.appColors;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (modalContext, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _kHomePadding,
              AppSpacing.md,
              _kHomePadding,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      context.tr('Период обзора', 'Reporting period'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Year selector
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setModalState(() => selectedYear--),
                            icon: const Icon(Icons.remove_rounded, size: 16),
                          ),
                          Text(
                            '$selectedYear',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setModalState(() => selectedYear++),
                            icon: const Icon(Icons.add_rounded, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) {
                    final selected = (i + 1) == dashboard.month &&
                        selectedYear == dashboard.year;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(modalContext);
                        dashboard.setMonth(selectedYear, i + 1);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected ? AppColors.primary : colors.border,
                          ),
                        ),
                        child: Text(
                          months[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Financial Bento Card ────────────────────────────────────────────────

class _HeroFinancialCard extends StatelessWidget {
  const _HeroFinancialCard({
    required this.hideBalances,
    required this.onTogglePrivacy,
  });

  final bool hideBalances;
  final VoidCallback onTogglePrivacy;

  @override
  Widget build(BuildContext context) {
    final income =
        context.select<DashboardProvider, int>((d) => d.incomeCents);
    final expense =
        context.select<DashboardProvider, int>((d) => d.expenseCents);
    final isRefreshing =
        context.select<DashboardProvider, bool>((d) => d.isRefreshing);
    final currency =
        context.select<SettingsProvider, String>((s) => s.currency);

    final net = income - expense;
    final totalFlow = income + expense;
    final incomeShare =
        totalFlow > 0 ? (income / totalFlow).clamp(0.0, 1.0) : 0.5;
    final isPositive = net >= 0;

    final marginPct = income > 0
        ? ((net / income) * 100).clamp(-999.0, 100.0)
        : 0.0;

    final netAccent = isPositive
        ? const Color(0xFF34D399)
        : const Color(0xFFFB7185);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF09191F),
            Color(0xFF0E3735),
            Color(0xFF115E59),
          ],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            CustomPaint(
              painter: const _HeroDecorPainter(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top status & privacy row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: netAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: netAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: netAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPositive
                                    ? context.tr('Чистая прибыль', 'Net profit')
                                    : context.tr('Убыток месяца', 'Monthly loss'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: netAccent,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (income > 0 && !hideBalances) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${marginPct >= 0 ? '+' : ''}${marginPct.toStringAsFixed(0)}% ${context.tr('маржа', 'margin')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        GestureDetector(
                          onTap: onTogglePrivacy,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hideBalances
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Main Net Balance (Auto-scales so it never overflows)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _AnimatedMoneyText(
                        cents: net.abs(),
                        currency: currency,
                        prefix: net < 0 ? '−' : (net > 0 ? '+' : ''),
                        hide: hideBalances,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                          height: 1.1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cashflow Split Progress Bar (direct flex, no ticker)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 6,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (incomeShare * 1000).round().clamp(1, 999),
                              child: Container(
                                color: const Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: ((1.0 - incomeShare) * 1000)
                                  .round()
                                  .clamp(1, 999),
                              child: Container(
                                color: totalFlow > 0
                                    ? const Color(0xFFFB7185)
                                    : Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Income & Expense Sub-cards (Zero overflow guaranteed)
                    Row(
                      children: [
                        Expanded(
                          child: _HeroSubMetric(
                            label: context.tr('Доходы', 'Income'),
                            cents: income,
                            currency: currency,
                            hideBalances: hideBalances,
                            accentColor: const Color(0xFF34D399),
                            icon: Icons.south_west_rounded,
                            onTap: () => context.go('/finance'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroSubMetric(
                            label: context.tr('Расходы', 'Expenses'),
                            cents: expense,
                            currency: currency,
                            hideBalances: hideBalances,
                            accentColor: const Color(0xFFFB7185),
                            icon: Icons.north_east_rounded,
                            onTap: () => context.go('/finance'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isRefreshing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF34D399),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroSubMetric extends StatelessWidget {
  const _HeroSubMetric({
    required this.label,
    required this.cents,
    required this.currency,
    required this.hideBalances,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int cents;
  final String currency;
  final bool hideBalances;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.11),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 13, color: accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _AnimatedMoneyText(
                cents: cents,
                currency: currency,
                hide: hideBalances,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight decorative circles painted on GPU without blur filters.
class _HeroDecorPainter extends CustomPainter {
  const _HeroDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.05);

    canvas.drawCircle(Offset(size.width * 0.9, -size.height * 0.1), 90, paint);
    canvas.drawCircle(Offset(size.width * 0.9, -size.height * 0.1), 135, paint);

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF14B8A6).withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 70, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Quick Actions Dock ───────────────────────────────────────────────────────

class _QuickActionsDock extends StatelessWidget {
  const _QuickActionsDock({required this.onAction});
  final Future<void> Function(String route) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Expanded(
          child: _QuickActionBtn(
            icon: Icons.add_circle_outline_rounded,
            label: context.tr('Доход', 'Income'),
            color: colors.income,
            onTap: () => onAction('/finance/new?type=income'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionBtn(
            icon: Icons.remove_circle_outline_rounded,
            label: context.tr('Расход', 'Expense'),
            color: colors.expense,
            onTap: () => onAction('/finance/new?type=expense'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionBtn(
            icon: Icons.receipt_long_outlined,
            label: context.tr('Заказ', 'Order'),
            color: colors.primary,
            onTap: () => onAction('/orders/new'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionBtn(
            icon: Icons.account_balance_wallet_outlined,
            label: context.tr('Долг', 'Debt'),
            color: colors.warning,
            onTap: () => onAction('/profile/debts/new'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _ScaleTap(
      onTap: onTap,
      scaleDown: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bento Business Overview Section ──────────────────────────────────────────

class _BentoStatsSection extends StatelessWidget {
  const _BentoStatsSection({
    required this.hideBalances,
  });

  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeOrdersCount = context
        .select<DashboardProvider, int>((d) => d.activeOrdersCount);
    final totalCustomersCount = context
        .select<DashboardProvider, int>((d) => d.totalCustomersCount);
    final receivableCents = context
        .select<DashboardProvider, int>((d) => d.receivableCents);
    final payableCents = context
        .select<DashboardProvider, int>((d) => d.payableCents);
    final currency =
        context.select<SettingsProvider, String>((s) => s.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.tr('Показатели бизнеса', 'Business overview'),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Top Row: Orders & Customers
        Row(
          children: [
            Expanded(
              child: _BentoMetricTile(
                icon: Icons.shopping_bag_outlined,
                badgeText: context.tr('В работе', 'Active'),
                title: context.tr('Заказы', 'Orders'),
                value: '$activeOrdersCount',
                accentColor: colors.primary,
                onTap: () => context.go('/orders'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BentoMetricTile(
                icon: Icons.people_alt_outlined,
                badgeText: context.tr('База', 'Base'),
                title: context.tr('Клиенты', 'Customers'),
                value: '$totalCustomersCount',
                accentColor: colors.income,
                onTap: () => context.go('/profile/customers'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Bottom Wide Bento Card: Debts Balance (Receivable & Payable)
        _ScaleTap(
          onTap: () => context.go('/profile/debts'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Контроль долгов', 'Debt tracker'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            context.tr(
                              'Дебиторская и кредиторская задолженность',
                              'Receivables & payables balance',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: colors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Нам должны', 'Owed to us'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _AnimatedMoneyText(
                                cents: receivableCents,
                                currency: currency,
                                hide: hideBalances,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: receivableCents > 0
                                      ? colors.warning
                                      : colors.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: colors.border,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Мы должны', 'We owe'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _AnimatedMoneyText(
                                cents: payableCents,
                                currency: currency,
                                hide: hideBalances,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: payableCents > 0
                                      ? colors.expense
                                      : colors.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BentoMetricTile extends StatelessWidget {
  const _BentoMetricTile({
    required this.icon,
    required this.badgeText,
    required this.title,
    required this.value,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String badgeText;
  final String title;
  final String value;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.1,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: colors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity Filter Bar ──────────────────────────────────────────────────────

class _ActivityFilterBar extends StatelessWidget {
  const _ActivityFilterBar({
    required this.selected,
    required this.allCount,
    required this.incomeCount,
    required this.expenseCount,
    required this.onChanged,
  });

  final _ActivityFilter selected;
  final int allCount;
  final int incomeCount;
  final int expenseCount;
  final ValueChanged<_ActivityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipPill(
            label: context.tr('Все', 'All'),
            count: allCount,
            active: selected == _ActivityFilter.all,
            onTap: () => onChanged(_ActivityFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipPill(
            label: context.tr('Доходы', 'Income'),
            count: incomeCount,
            active: selected == _ActivityFilter.income,
            accentColor: AppColors.income,
            onTap: () => onChanged(_ActivityFilter.income),
          ),
          const SizedBox(width: 8),
          _FilterChipPill(
            label: context.tr('Расходы', 'Expenses'),
            count: expenseCount,
            active: selected == _ActivityFilter.expense,
            accentColor: AppColors.expense,
            onTap: () => onChanged(_ActivityFilter.expense),
          ),
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeBg = accentColor ?? colors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeBg : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeBg : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Enriched Activity Tile ───────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.tx,
    required this.currency,
    required this.hideBalances,
  });

  final AppTransaction tx;
  final String currency;
  final bool hideBalances;

  static String _categoryLabel(String? category, String? linkedType) {
    if (linkedType == 'order_payment') return AppTr.tr('Заказ', 'Order');
    if (linkedType == 'debt_payment') return AppTr.tr('Долг', 'Debt');
    return switch (category) {
      'order_payment' => AppTr.tr('Заказ', 'Order'),
      'service' => AppTr.tr('Услуга', 'Service'),
      'sale' => AppTr.tr('Продажа', 'Sale'),
      'refund_received' => AppTr.tr('Возврат', 'Refund'),
      'other_income' => AppTr.tr('Доход', 'Income'),
      'supplies' => AppTr.tr('Материалы', 'Supplies'),
      'rent' => AppTr.tr('Аренда', 'Rent'),
      'utilities' => AppTr.tr('Коммуналка', 'Utilities'),
      'transport' => AppTr.tr('Транспорт', 'Transport'),
      'marketing' => AppTr.tr('Маркетинг', 'Marketing'),
      'salary' => AppTr.tr('Зарплата', 'Salary'),
      'equipment' => AppTr.tr('Оборудование', 'Equipment'),
      'other_expense' => AppTr.tr('Расход', 'Expense'),
      'debt_received' => AppTr.tr('Долг', 'Debt'),
      'debt_paid' => AppTr.tr('Выплата долга', 'Debt payment'),
      _ => AppTr.tr('Операция', 'Transaction'),
    };
  }

  static IconData _categoryIcon(
    String? category,
    String? linkedType,
    bool isIncome,
  ) {
    if (linkedType == 'order_payment' || category == 'order_payment') {
      return Icons.shopping_bag_outlined;
    }
    if (linkedType == 'debt_payment' ||
        category == 'debt_received' ||
        category == 'debt_paid') {
      return Icons.account_balance_wallet_outlined;
    }
    return switch (category) {
      'service' => Icons.handyman_outlined,
      'sale' => Icons.storefront_outlined,
      'supplies' => Icons.inventory_2_outlined,
      'rent' => Icons.home_work_outlined,
      'transport' => Icons.local_shipping_outlined,
      'marketing' => Icons.campaign_outlined,
      'salary' => Icons.badge_outlined,
      'equipment' => Icons.precision_manufacturing_outlined,
      _ => isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = tx.type == TransactionType.income;
    final tileColor = isIncome ? colors.income : colors.expense;
    final sign = isIncome ? '+' : '−';
    final catName = _categoryLabel(tx.category, tx.linkedEntityType);
    final label =
        tx.description?.isNotEmpty == true ? tx.description! : catName;
    final iconData = _categoryIcon(tx.category, tx.linkedEntityType, isIncome);
    final amountText = hideBalances
        ? '•••• $currency'
        : '$sign${FinancialCalculator.formatCents(tx.amountCents, currency: currency)}';
    final isLargeAmount = amountText.length > 13;

    return InkWell(
      onTap: () => context.go('/finance'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: isLargeAmount
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            // Category-aware icon badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconData,
                size: 18,
                color: tileColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            catName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          DateHelper.relativeDate(tx.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isLargeAmount) ...[
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amountText,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tileColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isLargeAmount) ...[
              const SizedBox(width: 8),
              Text(
                amountText,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tileColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
