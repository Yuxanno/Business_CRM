import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';
import '../../components/app_card.dart';

const double _kPagePadding = 20.0;

enum _FinanceTab { all, income, expense }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _searchCtrl = TextEditingController();

  _FinanceTab _activeTab = _FinanceTab.all;
  String? _selectedCategory;
  bool _searchOpen = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonth();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    final provider = context.read<FinanceProvider>();
    final now = DateTime.now();
    await provider.loadMonth(
      provider.selectedYear != 0 ? provider.selectedYear : now.year,
      provider.selectedMonth != 0 ? provider.selectedMonth : now.month,
    );
  }

  Future<void> _reload() async {
    HapticFeedback.mediumImpact();
    await context.read<FinanceProvider>().reload();
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _shiftMonth(int delta) async {
    HapticFeedback.selectionClick();
    final provider = context.read<FinanceProvider>();
    var month = provider.selectedMonth + delta;
    var year = provider.selectedYear;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    setState(() => _selectedCategory = null);
    await provider.loadMonth(year, month);
  }

  Future<void> _openForm(String route) async {
    HapticFeedback.lightImpact();
    await context.push(route);
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _showAddSheet() async {
    HapticFeedback.selectionClick();
    final colors = context.appColors;
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 340),
        reverseDuration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _kPagePadding,
            AppSpacing.md,
            _kPagePadding,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(Icons.south_west_rounded,
                    color: AppColors.primary),
                title: Text(context.tr('Добавить доход', 'Add income')),
                onTap: () => Navigator.pop(ctx, 'income'),
              ),
              ListTile(
                leading: Icon(Icons.north_east_rounded,
                    color: Colors.red.shade400),
                title: Text(context.tr('Добавить расход', 'Add expense')),
                onTap: () => Navigator.pop(ctx, 'expense'),
              ),
            ],
          ),
        ),
      ),
    );
    if (type != null && mounted) {
      await _openForm('/finance/new?type=$type');
    }
  }

  List<AppTransaction> _filterTransactions(List<AppTransaction> all) {
    return all.where((tx) {
      if (_activeTab == _FinanceTab.income &&
          tx.type != TransactionType.income) {
        return false;
      }
      if (_activeTab == _FinanceTab.expense &&
          tx.type != TransactionType.expense) {
        return false;
      }
      if (_selectedCategory != null && tx.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final desc = (tx.description ?? '').toLowerCase();
        final cat = _CategoryMeta.label(tx.category, tx.linkedEntityType)
            .toLowerCase();
        final notes = (tx.notes ?? '').toLowerCase();
        if (!desc.contains(q) && !cat.contains(q) && !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<FinanceProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final allTx = provider.transactions;
    final filteredTx = _filterTransactions(allTx);

    final incomeCount = provider.incomeCount;
    final expenseCount = provider.expenseCount;

    // Collect categories present in current tab
    final tabTx = switch (_activeTab) {
      _FinanceTab.all => allTx,
      _FinanceTab.income =>
        allTx.where((t) => t.type == TransactionType.income).toList(),
      _FinanceTab.expense =>
        allTx.where((t) => t.type == TransactionType.expense).toList(),
    };
    final availableCategories = <String>{
      for (final t in tabTx)
        if (t.category != null && t.category!.isNotEmpty) t.category!,
    }.toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Pinned Top Bar (Title, Search Toggle, Month Pill, +) ───
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                0,
              ),
              child: _FinanceTopBar(
                year: provider.selectedYear,
                month: provider.selectedMonth,
                searchOpen: _searchOpen,
                searchController: _searchCtrl,
                onToggleSearch: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    }
                  });
                },
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onAdd: _showAddSheet,
                onPrevMonth: () => _shiftMonth(-1),
                onNextMonth: () => _shiftMonth(1),
                onPickMonth: (y, m) async {
                  setState(() => _selectedCategory = null);
                  await provider.loadMonth(y, m);
                },
              ),
            ),

            // ── 2. Pinned Segmented Filter Tabs & Category Pills ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SegmentedTabBar(
                    activeTab: _activeTab,
                    allCount: provider.totalCount,
                    incomeCount: incomeCount,
                    expenseCount: expenseCount,
                    onChanged: (tab) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activeTab = tab;
                        _selectedCategory = null;
                      });
                    },
                  ),
                  if (availableCategories.length > 1) ...[
                    const SizedBox(height: 10),
                    _CategoryFilterStrip(
                      categories: availableCategories,
                      selected: _selectedCategory,
                      onSelect: (cat) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ── 3. Scrollable Transactions List ───────────────────────────
            Expanded(
              child: (provider.isLoading ||
                      (!provider.hasLoadedOnce &&
                          provider.error == null &&
                          allTx.isEmpty))
                  ? const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          _kPagePadding,
                          AppSpacing.md,
                          _kPagePadding,
                          100,
                        ),
                        child: AppSkeletonList(count: 4),
                      ),
                    )
                  : RefreshIndicator(
                      color: colors.primary,
                      backgroundColor: colors.surface,
                      onRefresh: _reload,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 320 &&
                              provider.hasMore &&
                              !provider.isLoadingMore) {
                            provider.loadMore();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [

              // ── 4. Transactions List or Empty State ───────────────────────
              if (filteredTx.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kPagePadding,
                      vertical: AppSpacing.xl,
                    ),
                    child: AppEmptyState(
                      icon: _activeTab == _FinanceTab.expense
                          ? Icons.north_east_rounded
                          : Icons.receipt_long_outlined,
                      title: _searchQuery.isNotEmpty ||
                              _selectedCategory != null
                          ? context.tr(
                              'Операции не найдены',
                              'No transactions found',
                            )
                          : (_activeTab == _FinanceTab.income
                              ? context.tr(
                                  'Нет доходов за этот месяц',
                                  'No income this month',
                                )
                              : _activeTab == _FinanceTab.expense
                                  ? context.tr(
                                      'Нет расходов за этот месяц',
                                      'No expenses this month',
                                    )
                                  : context.tr(
                                      'В этом месяце пока пусто',
                                      'No transactions this month',
                                    )),
                      subtitle: _searchQuery.isNotEmpty ||
                              _selectedCategory != null
                          ? context.tr(
                              'Попробуйте сбросить фильтр или изменить запрос',
                              'Try clearing the filter or changing your search',
                            )
                          : context.tr(
                              'Запишите доход или расход, чтобы видеть аналитику месяца',
                              'Record income or expenses to see monthly analytics',
                            ),
                      actionLabel: _searchQuery.isNotEmpty ||
                              _selectedCategory != null
                          ? context.tr('Сбросить фильтр', 'Reset filter')
                          : (_activeTab == _FinanceTab.expense
                              ? context.tr('Добавить расход', 'Add expense')
                              : context.tr('Добавить доход', 'Add income')),
                      onAction: () {
                        if (_searchQuery.isNotEmpty ||
                            _selectedCategory != null) {
                          setState(() {
                            _searchQuery = '';
                            _searchCtrl.clear();
                            _selectedCategory = null;
                          });
                        } else {
                          final type = _activeTab == _FinanceTab.expense
                              ? 'expense'
                              : 'income';
                          _openForm('/finance/new?type=$type');
                        }
                      },
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _kPagePadding,
                    AppSpacing.sm,
                    _kPagePadding,
                    110,
                  ),
                  sliver: _GroupedTransactionsSliver(
                    transactions: filteredTx,
                    currency: currency,
                    onEdit: (tx) => _openForm('/finance/edit/${tx.id}'),
                    onDelete: (tx) async {
                      final confirm = await showConfirmSheet(
                        context: context,
                        title: context.tr(
                          'Удалить операцию?',
                          'Delete transaction?',
                        ),
                        message: context.tr(
                          'Операция будет удалена, а итоги месяца пересчитаются.',
                          'The transaction will be deleted and monthly totals recalculated.',
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context.read<FinanceProvider>().delete(tx.id);
                        if (context.mounted) {
                          context.read<DashboardProvider>().reload();
                        }
                      }
                    },
                  ),
                ),
              if (provider.isLoadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                    ],
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

// ─── 1. Top Bar with Search & Month Selector ─────────────────────────────────

class _FinanceTopBar extends StatelessWidget {
  const _FinanceTopBar({
    required this.year,
    required this.month,
    required this.searchOpen,
    required this.searchController,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickMonth,
  });

  final int year;
  final int month;
  final bool searchOpen;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(int year, int month) onPickMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selectedDate = DateTime(year, month);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: searchOpen
          ? Container(
              key: const ValueKey('search-bar'),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'Поиск по описанию или категории...',
                          'Search by description or category...',
                        ),
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleSearch,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Row(
              key: const ValueKey('title-bar'),
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('Деньги', 'Finance'),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Search icon button
                GestureDetector(
                  onTap: onToggleSearch,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Month pill
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onPrevMonth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showMonthModal(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 13,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateHelper.formatMonthYear(selectedDate),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
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
                        onTap: onNextMonth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                const SizedBox(width: 6),
                // Add operation button
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showMonthModal(BuildContext context) async {
    HapticFeedback.selectionClick();
    var selectedYear = year;
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
              _kPagePadding,
              AppSpacing.md,
              _kPagePadding,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      context.tr('Выберите месяц', 'Select month'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
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
                    final selected =
                        (i + 1) == month && selectedYear == year;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(modalContext);
                        onPickMonth(selectedYear, i + 1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : colors.border,
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

// ─── 2. Segmented Tab Bar & Category Filter Strip ────────────────────────────

class _SegmentedTabBar extends StatelessWidget {
  const _SegmentedTabBar({
    required this.activeTab,
    required this.allCount,
    required this.incomeCount,
    required this.expenseCount,
    required this.onChanged,
  });

  final _FinanceTab activeTab;
  final int allCount;
  final int incomeCount;
  final int expenseCount;
  final ValueChanged<_FinanceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final alignX = switch (activeTab) {
      _FinanceTab.all => -1.0,
      _FinanceTab.income => 0.0,
      _FinanceTab.expense => 1.0,
    };
    final pillColor = switch (activeTab) {
      _FinanceTab.all => colors.primary,
      _FinanceTab.income => colors.income,
      _FinanceTab.expense => colors.expense,
    };

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignX, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: pillColor.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _SegTabItem(
                label: context.tr('Все', 'All'),
                count: allCount,
                selected: activeTab == _FinanceTab.all,
                onTap: () => onChanged(_FinanceTab.all),
              ),
              _SegTabItem(
                label: context.tr('Доходы', 'Income'),
                count: incomeCount,
                selected: activeTab == _FinanceTab.income,
                onTap: () => onChanged(_FinanceTab.income),
              ),
              _SegTabItem(
                label: context.tr('Расходы', 'Expenses'),
                count: expenseCount,
                selected: activeTab == _FinanceTab.expense,
                onTap: () => onChanged(_FinanceTab.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegTabItem extends StatelessWidget {
  const _SegTabItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : colors.textSecondary,
                    ),
                    child: Text(label, maxLines: 1),
                  ),
                  const SizedBox(width: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : colors.textMuted,
                      ),
                      child: Text('$count'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterStrip extends StatelessWidget {
  const _CategoryFilterStrip({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => onSelect(null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == null ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == null ? colors.primary : colors.border,
                ),
              ),
              child: Text(
                context.tr('Все категории', 'All categories'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      selected == null ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
          ),
          for (final cat in categories) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onSelect(selected == cat ? null : cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == cat
                      ? colors.primary.withValues(alpha: 0.14)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected == cat ? colors.primary : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _CategoryMeta.icon(cat, null, true),
                      size: 13,
                      color: selected == cat
                          ? colors.primary
                          : colors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _CategoryMeta.label(cat, null),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected == cat
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected == cat
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 4. Grouped Transactions Sliver ──────────────────────────────────────────

class _GroupedTransactionsSliver extends StatelessWidget {
  const _GroupedTransactionsSliver({
    required this.transactions,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AppTransaction> transactions;
  final String currency;
  final ValueChanged<AppTransaction> onEdit;
  final ValueChanged<AppTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final Map<String, List<AppTransaction>> grouped = {};
    final Map<String, DateTime> dateMap = {};
    for (final tx in transactions) {
      final key = DateHelper.formatDate(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
      dateMap.putIfAbsent(key, () => tx.date);
    }
    final keys = grouped.keys.toList();

    return SliverList.builder(
      addAutomaticKeepAlives: false,
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final dateKey = keys[i];
          final dateObj = dateMap[dateKey]!;
          final txs = grouped[dateKey]!;

          final dayIncome = txs
              .where((t) => t.type == TransactionType.income)
              .fold(0, (s, t) => s + t.amountCents);
          final dayExpense = txs
              .where((t) => t.type == TransactionType.expense)
              .fold(0, (s, t) => s + t.amountCents);

          final relative = DateHelper.relativeDate(dateObj);
          final showRelative = relative == context.tr('Сегодня', 'Today') ||
              relative == context.tr('Вчера', 'Yesterday');

          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                  child: Row(
                    children: [
                      if (showRelative) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            relative,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        dateKey,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (dayIncome > 0)
                        Text(
                          '+${FinancialCalculator.formatCentsCompact(dayIncome, currency: currency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.income,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      if (dayIncome > 0 && dayExpense > 0)
                        Text(
                          '  •  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      if (dayExpense > 0)
                        Text(
                          '−${FinancialCalculator.formatCentsCompact(dayExpense, currency: currency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.expense,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),

                // Day transactions card
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  radius: AppRadius.cardLarge,
                  child: Column(
                    children: [
                      for (int j = 0; j < txs.length; j++) ...[
                        if (j > 0)
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: AppSpacing.md,
                            color: colors.divider.withValues(alpha: 0.7),
                          ),
                        _TransactionRowTile(
                          tx: txs[j],
                          currency: currency,
                          onEdit: () => onEdit(txs[j]),
                          onDelete: () => onDelete(txs[j]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
      },
    );
  }
}

class _TransactionRowTile extends StatelessWidget {
  const _TransactionRowTile({
    required this.tx,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final AppTransaction tx;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isIncome = tx.type == TransactionType.income;
    final isLinked = tx.linkedEntityType == 'order_payment' ||
        tx.linkedEntityType == 'debt_payment';
    final tileColor = isIncome ? colors.income : colors.expense;
    final sign = isIncome ? '+' : '−';
    final catLabel = _CategoryMeta.label(tx.category, tx.linkedEntityType);
    final title =
        tx.description?.isNotEmpty == true ? tx.description! : catLabel;
    final iconData =
        _CategoryMeta.icon(tx.category, tx.linkedEntityType, isIncome);
    final amountText =
        '$sign${FinancialCalculator.formatCents(tx.amountCents, currency: currency)}';
    final isLargeAmount = amountText.length > 13;

    return InkWell(
      onTap: isLinked ? null : onEdit,
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
            // Category Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                iconData,
                size: 19,
                color: tileColor,
              ),
            ),
            const SizedBox(width: 12),

            // Title + Category Badge + Notes (+ Amount below if large)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
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
                            catLabel,
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
                      if (isLinked) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.link_rounded,
                          size: 12,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            tx.linkedEntityType == 'order_payment'
                                ? context.tr('По заказу', 'For order')
                                : context.tr('По долгу', 'For debt'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ] else if (tx.notes?.isNotEmpty == true) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tx.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
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
            const SizedBox(width: 8),

            // Amount (inline when compact) + Actions
            if (!isLargeAmount)
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
            if (!isLinked) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: colors.expense,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Category Metadata Helper ────────────────────────────────────────────────

class _CategoryMeta {
  static String label(String? category, String? linkedType) {
    if (linkedType == 'order_payment') {
      return AppTr.tr('Оплата заказа', 'Order payment');
    }
    if (linkedType == 'debt_payment') {
      return AppTr.tr('Погашение долга', 'Debt payment');
    }
    if (category != null &&
        TransactionCategories.customLabels.containsKey(category)) {
      return TransactionCategories.customLabels[category]!;
    }
    return switch (category) {
      'order_payment' => AppTr.tr('Оплата заказа', 'Order payment'),
      'service' => AppTr.tr('Услуга', 'Service'),
      'sale' => AppTr.tr('Продажа', 'Sale'),
      'refund_received' => AppTr.tr('Возврат', 'Refund'),
      'other_income' => AppTr.tr('Прочий доход', 'Other income'),
      'supplies' => AppTr.tr('Материалы', 'Supplies'),
      'rent' => AppTr.tr('Аренда', 'Rent'),
      'utilities' => AppTr.tr('Коммуналка', 'Utilities'),
      'transport' => AppTr.tr('Транспорт', 'Transport'),
      'marketing' => AppTr.tr('Маркетинг', 'Marketing'),
      'salary' => AppTr.tr('Зарплата', 'Salary'),
      'equipment' => AppTr.tr('Оборудование', 'Equipment'),
      'other_expense' => AppTr.tr('Прочий расход', 'Other expense'),
      'debt_received' => AppTr.tr('Получен долг', 'Debt received'),
      'debt_paid' => AppTr.tr('Выплата долга', 'Debt payment'),
      final String custom when custom.isNotEmpty => custom,
      _ => AppTr.tr('Операция', 'Transaction'),
    };
  }

  static IconData icon(
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
      'refund_received' => Icons.replay_rounded,
      'supplies' => Icons.inventory_2_outlined,
      'rent' => Icons.home_work_outlined,
      'utilities' => Icons.bolt_rounded,
      'transport' => Icons.local_shipping_outlined,
      'marketing' => Icons.campaign_outlined,
      'salary' => Icons.badge_outlined,
      'equipment' => Icons.precision_manufacturing_outlined,
      _ => isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
    };
  }
}
