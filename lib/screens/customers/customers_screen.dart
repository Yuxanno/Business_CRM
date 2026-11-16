import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';
import '../../l10n/app_tr.dart';

const double _kPagePadding = 20.0;

enum _CustomerFilter { all, withDebt, withOrders }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;
  _CustomerFilter _selectedFilter = _CustomerFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().load();
      final dp = context.read<DebtProvider>();
      if (dp.all.isEmpty && !dp.isLoading) {
        dp.load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _closeSearch(CustomerProvider provider) {
    setState(() => _searchActive = false);
    _searchCtrl.clear();
    provider.setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<CustomerProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    int totalDebtFor(Customer c) =>
        c.outstandingBalanceCents +
        debtProvider.remainingDebtForCustomer(c.id, c.name);

    final baseList = provider.customers;
    final allCount = provider.totalCount;
    final withDebtCount = provider.withDebtCountFromServer ??
        baseList.where((c) => totalDebtFor(c) > 0).length;
    final withOrdersCount = provider.withOrdersCount;

    final filtered = switch (_selectedFilter) {
      _CustomerFilter.all => baseList,
      _CustomerFilter.withDebt =>
        baseList.where((c) => totalDebtFor(c) > 0).toList(),
      _CustomerFilter.withOrders =>
        baseList.where((c) => c.totalOrdersCount > 0).toList(),
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Top Bar with Back, Title, Search & "+ Новый" ───────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                AppSpacing.xs,
              ),
              child: _CustomersTopBar(
                totalCount: provider.totalCount,
                searchActive: _searchActive,
                searchCtrl: _searchCtrl,
                onBack: () {
                  HapticFeedback.selectionClick();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/profile');
                  }
                },
                onOpenSearch: () {
                  HapticFeedback.selectionClick();
                  setState(() => _searchActive = true);
                },
                onCloseSearch: () => _closeSearch(provider),
                onSearchChanged: provider.setSearch,
                onNewCustomer: () {
                  HapticFeedback.mediumImpact();
                  context.push('/profile/customers/new');
                },
              ),
            ),

            // ── 2. Filter Strip (Все / С долгом / С заказами) ─────────────
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: _CustomerFilterStrip(
                selected: _selectedFilter,
                allCount: allCount,
                withDebtCount: withDebtCount,
                withOrdersCount: withOrdersCount,
                onSelect: (f) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = f);
                },
              ),
            ),

            // ── 3. Customer List ──────────────────────────────────────────
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
                child: provider.isLoading
                    ? const Align(
                        key: ValueKey('skeleton'),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: _kPagePadding),
                          child: AppSkeletonList(count: 5),
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('content'),
                        child: filtered.isEmpty
                      ? AppEmptyState(
                          icon: Icons.people_outline_rounded,
                          title: _searchActive && _searchCtrl.text.isNotEmpty
                              ? context.tr('Клиенты не найдены',
                                  'No customers found')
                              : _selectedFilter != _CustomerFilter.all
                                  ? context.tr('В этой категории пусто',
                                      'Nothing in this category')
                                  : context.tr('Клиентов пока нет',
                                      'No customers yet'),
                          subtitle: _searchActive && _searchCtrl.text.isNotEmpty
                              ? context.tr(
                                  'Попробуйте изменить поисковый запрос',
                                  'Try a different search query')
                              : _selectedFilter != _CustomerFilter.all
                                  ? context.tr(
                                      'Переключите фильтр на «Все» или добавьте клиента',
                                      'Switch filter to "All" or add a customer')
                                  : context.tr(
                                      'Добавьте клиента — заказы и платежи привяжутся к его профилю',
                                      'Add a customer — orders and payments will link to their profile'),
                          actionLabel:
                              (_searchActive && _searchCtrl.text.isNotEmpty) ||
                                      _selectedFilter != _CustomerFilter.all
                                  ? context.tr('Показать всех', 'Show all')
                                  : context.tr('Добавить клиента',
                                      'Add customer'),
                          onAction: () {
                            if (_searchActive && _searchCtrl.text.isNotEmpty) {
                              _closeSearch(provider);
                            } else if (_selectedFilter != _CustomerFilter.all) {
                              setState(
                                () => _selectedFilter = _CustomerFilter.all,
                              );
                            } else {
                              context.push('/profile/customers/new');
                            }
                          },
                        )
                      : RefreshIndicator(
                          color: colors.primary,
                          backgroundColor: colors.surface,
                          onRefresh: () async {
                            await Future.wait([
                              context.read<CustomerProvider>().load(),
                              context.read<DebtProvider>().load(),
                            ]);
                          },
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.pixels >=
                                      notification.metrics.maxScrollExtent -
                                          320 &&
                                  provider.hasMore &&
                                  !provider.isLoadingMore) {
                                provider.loadMore();
                              }
                              return false;
                            },
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
                              itemCount: filtered.length +
                                  (provider.isLoadingMore ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (i >= filtered.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                                  );
                                }
                                final c = filtered[i];
                                final extraDebt = debtProvider
                                    .remainingDebtForCustomer(c.id, c.name);
                                final debtsCount = debtProvider
                                    .debtsForCustomer(c.id, c.name)
                                    .length;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: RepaintBoundary(
                                    child: _ModernCustomerCard(
                                      customer: c,
                                      extraDebtCents: extraDebt,
                                      debtsCount: debtsCount,
                                      currency: currency,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        context.go('/profile/customers/${c.id}');
                                      },
                                      onEdit: () async {
                                        HapticFeedback.selectionClick();
                                        await context.push(
                                          '/profile/customers/${c.id}/edit',
                                        );
                                        if (context.mounted) {
                                          context
                                              .read<CustomerProvider>()
                                              .load();
                                        }
                                      },
                                      onDelete: () =>
                                          _confirmDelete(context, c),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Customer customer) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить клиента?', 'Delete customer?'),
      message: context.tr(
          'Клиент «${customer.name}» будет удалён. История его заказов сохранится.',
          'Customer "${customer.name}" will be deleted. Their order history will be preserved.'),
    );
    if (confirm == true && context.mounted) {
      await context.read<CustomerProvider>().delete(customer.id);
    }
  }
}

// ─── 1. Top Bar ──────────────────────────────────────────────────────────────

class _CustomersTopBar extends StatelessWidget {
  const _CustomersTopBar({
    required this.totalCount,
    required this.searchActive,
    required this.searchCtrl,
    required this.onBack,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onNewCustomer,
  });

  final int totalCount;
  final bool searchActive;
  final TextEditingController searchCtrl;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewCustomer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: searchActive
          ? Container(
              key: const ValueKey('customers_search'),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 19, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('Имя или телефон клиента…',
                            'Customer name or phone…'),
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
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
                    onTap: onCloseSearch,
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
              key: const ValueKey('customers_title'),
              children: [
                GestureDetector(
                  onTap: onBack,
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
                  context.tr('Клиенты', 'Customers'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: colors.textPrimary,
                  ),
                ),
                if (totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: onOpenSearch,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onNewCustomer,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Новый', 'New'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── 2. Filter Strip ─────────────────────────────────────────────────────────

class _CustomerFilterStrip extends StatelessWidget {
  const _CustomerFilterStrip({
    required this.selected,
    required this.allCount,
    required this.withDebtCount,
    required this.withOrdersCount,
    required this.onSelect,
  });

  final _CustomerFilter selected;
  final int allCount;
  final int withDebtCount;
  final int withOrdersCount;
  final ValueChanged<_CustomerFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final items = [
      (
        filter: _CustomerFilter.all,
        label: context.tr('Все', 'All'),
        count: allCount,
        dotColor: null,
      ),
      (
        filter: _CustomerFilter.withDebt,
        label: context.tr('С долгом', 'With debt'),
        count: withDebtCount,
        dotColor: colors.warning,
      ),
      (
        filter: _CustomerFilter.withOrders,
        label: context.tr('С заказами', 'With orders'),
        count: withOrdersCount,
        dotColor: colors.income,
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item.filter;

          return GestureDetector(
            onTap: () => onSelect(item.filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.dotColor != null && !isSelected) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 3. Balanced Medium-Minimalist Customer Card ─────────────────────────────

class _ModernCustomerCard extends StatelessWidget {
  const _ModernCustomerCard({
    required this.customer,
    required this.extraDebtCents,
    required this.debtsCount,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final int extraDebtCents;
  final int debtsCount;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalDebtCents = customer.outstandingBalanceCents + extraDebtCents;
    final hasDebt = totalDebtCents > 0;
    final hasActivity = customer.totalOrdersCount > 0 || debtsCount > 0;
    final hasPhone =
        customer.phone != null && customer.phone!.trim().isNotEmpty;
    final hasEmail =
        customer.email != null && customer.email!.trim().isNotEmpty;

    final avatarColor =
        hasDebt ? const Color(0xFFD97706) : colors.primary;
    final initials = _initials(customer.name);

    String subtitleText;
    IconData subtitleIcon;
    if (hasPhone) {
      subtitleText = customer.phone!.trim();
      subtitleIcon = Icons.phone_outlined;
    } else if (hasEmail) {
      subtitleText = customer.email!.trim();
      subtitleIcon = Icons.alternate_email_rounded;
    } else {
      subtitleText = context.tr('Контакты не указаны', 'No contacts');
      subtitleIcon = Icons.person_outline_rounded;
    }

    return Slidable(
      key: ValueKey('customer_${customer.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: context.tr('Изменить', 'Edit'),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(14),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: colors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: context.tr('Удалить', 'Delete'),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(14),
            ),
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Avatar + Name/Phone (Left) | Status/Debt Badge (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 15,
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
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            subtitleIcon,
                            size: 12,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (hasDebt)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FinancialCalculator.formatCents(
                          totalDebtCents,
                          currency: currency,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          extraDebtCents > 0 && customer.outstandingBalanceCents == 0
                              ? context.tr('Долг клиента', 'Customer debt')
                              : context.tr('Есть долг', 'Has debt'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? colors.income
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasActivity
                          ? context.tr('Без долгов', 'No debt')
                          : context.tr('Новый', 'New'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasActivity
                            ? Colors.white
                            : colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 9),

            // ── Row 2: Orders & Paid Stats (Left) | Quick Action Icons (Right)
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 13,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('Заказов: ${customer.totalOrdersCount}',
                      'Orders: ${customer.totalOrdersCount}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                if (customer.totalReceivedCents > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(
                          'Оплачено: ${FinancialCalculator.formatCentsCompact(customer.totalReceivedCents, currency: currency)}',
                          'Paid: ${FinancialCalculator.formatCentsCompact(customer.totalReceivedCents, currency: currency)}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.income,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 6),
                // Edit quick button
                _CardIconAction(
                  icon: Icons.edit_outlined,
                  color: colors.textSecondary,
                  bgColor: colors.background,
                  borderColor: colors.border,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                // Delete quick button
                _CardIconAction(
                  icon: Icons.delete_outline_rounded,
                  color: colors.expense,
                  bgColor: colors.background,
                  borderColor: colors.border,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
  }
}

class _CardIconAction extends StatelessWidget {
  const _CardIconAction({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
