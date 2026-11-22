import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/debt.dart';
import '../../models/order.dart';
import '../../providers/customer_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/app_skeleton.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

const double _kPagePadding = 20.0;

enum _DebtFilter { all, active, overdue, paid }

enum _DebtSourceFilter { all, orders, other }

/// Unified item representing either a standalone [Debt] or an unpaid [Order].
class _DebtEntry {
  const _DebtEntry.debt(Debt this.debt) : order = null;
  const _DebtEntry.order(Order this.order) : debt = null;

  final Debt? debt;
  final Order? order;

  bool get isOrder => order != null;

  String get id => order?.id ?? debt!.id;
  String get personName => order?.customerName ?? debt!.personName;
  String? get description => order?.title ?? debt!.description;
  int get originalAmountCents =>
      order?.totalPriceCents ?? debt!.originalAmountCents;
  int get paidAmountCents => order?.receivedCents ?? debt!.paidAmountCents;
  int get remainingCents => order?.remainingCents ?? debt!.remainingCents;
  bool get isFullyPaid => order?.isFullyPaid ?? debt!.isFullyPaid;
  DateTime get createdAt => order?.createdAt ?? debt!.createdAt;
  DateTime? get dueDate => order?.dueDate ?? debt!.dueDate;

  DebtStatus get computedStatus {
    if (debt != null) return debt!.computedStatus;
    final o = order!;
    if (o.isFullyPaid) return DebtStatus.paid;
    if (o.dueDate != null && DateTime.now().isAfter(o.dueDate!)) {
      return DebtStatus.overdue;
    }
    if (o.receivedCents > 0) return DebtStatus.partiallyPaid;
    return DebtStatus.unpaid;
  }
}

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _searchCtrl = TextEditingController();
  DebtDirection _direction = DebtDirection.receivable;
  _DebtFilter _statusFilter = _DebtFilter.all;
  _DebtSourceFilter _sourceFilter = _DebtSourceFilter.all;
  bool _searchActive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _direction = context.read<DebtProvider>().selectedDirection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().load();
      final op = context.read<OrderProvider>();
      if (op.allOrders.isEmpty && !op.isLoading) {
        op.load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    HapticFeedback.mediumImpact();
    await Future.wait([
      context.read<DebtProvider>().load(force: true),
      context.read<OrderProvider>().load(silent: true, force: true),
    ]);
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _openForm(String route) async {
    HapticFeedback.lightImpact();
    await context.push(route);
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Debt debt) async {
    HapticFeedback.selectionClick();
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить долг?', 'Delete debt?'),
      message: context.tr(
          'Запись «${debt.personName}» и вся история погашений будут удалены безвозвратно.',
          'Record "${debt.personName}" and all payment history will be permanently deleted.'),
    );
    if (confirm == true && context.mounted) {
      await context.read<DebtProvider>().delete(debt.id);
      if (context.mounted) {
        context.read<DashboardProvider>().reload();
      }
    }
  }

  void _showPaymentSheet(BuildContext context, Debt debt) {
    HapticFeedback.lightImpact();
    final colors = context.appColors;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final isReceivable = debt.direction == DebtDirection.receivable;
    final accentColor = isReceivable ? colors.income : colors.expense;
    final currency = context.read<SettingsProvider>().currency;
    final remainingCents = debt.remainingCents;
    final formattedRemaining =
        FinancialCalculator.formatCents(remainingCents, currency: currency);

    showAppModal(
      context: context,
      child: AppModalSheet(
        title: isReceivable
            ? context.tr('Принять возврат долга', 'Receive debt payment')
            : context.tr('Выплатить по долгу', 'Pay debt'),
        subtitle: context.tr('${debt.personName} · Остаток: $formattedRemaining',
            '${debt.personName} · Remaining: $formattedRemaining'),
        headerIcon: isReceivable
            ? Icons.south_west_rounded
            : Icons.north_east_rounded,
        headerColor: accentColor,
        bottomBar: FormSubmitButton(
          label: isReceivable
              ? context.tr('Зачислить возврат', 'Record receipt')
              : context.tr('Списать выплату', 'Record payment'),
          accentColor: accentColor,
          isLoading: false,
          icon: Icons.check_rounded,
          onPressed: () async {
            final cents =
                FinancialCalculator.parseAmountToCents(amountCtrl.text);
            if (cents == null || cents <= 0) return;
            Navigator.of(context, rootNavigator: true).pop();
            HapticFeedback.mediumImpact();
            final debtProvider = context.read<DebtProvider>();
            final dashboardProvider = context.read<DashboardProvider>();
            const uuid = Uuid();
            await debtProvider.recordPayment(
                  debtId: debt.id,
                  amountCents: cents.clamp(0, remainingCents),
                  paymentId: uuid.v4(),
                  transactionId: uuid.v4(),
                  notes: notesCtrl.text.trim().isNotEmpty
                      ? notesCtrl.text.trim()
                      : null,
                );
            dashboardProvider.reload();
          },
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          shrinkWrap: true,
          children: [
            SheetField(
              label: context.tr('СУММА ПОГАШЕНИЯ', 'PAYMENT AMOUNT'),
              required: true,
              trailingLabel: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  amountCtrl.text = remainingCents % 100 == 0
                      ? (remainingCents ~/ 100).toString()
                      : (remainingCents / 100).toStringAsFixed(2);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Весь остаток ($formattedRemaining)',
                        'Full balance ($formattedRemaining)'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              child: FormAmountField(
                controller: amountCtrl,
                accentColor: accentColor,
                prefix: isReceivable ? '+' : '−',
                currency: currency,
                autofocus: true,
              ),
            ),
            const SizedBox(height: 16),
            SheetField(
              label: context.tr('ЗАМЕТКА К ВЫПЛАТЕ', 'PAYMENT NOTE'),
              child: FormTextField(
                controller: notesCtrl,
                prefixIcon: Icons.notes_rounded,
                hint: context.tr('Наличные, перевод на карту и т.д.',
                    'Cash, card transfer, etc.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderPaymentSheet(BuildContext context, Order order) {
    HapticFeedback.lightImpact();
    final colors = context.appColors;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final currency = context.read<SettingsProvider>().currency;
    final remainingCents = order.remainingCents;
    final formattedRemaining =
        FinancialCalculator.formatCents(remainingCents, currency: currency);

    showAppModal(
      context: context,
      child: AppModalSheet(
        title: context.tr('Оплата по заказу', 'Order payment'),
        subtitle: context.tr(
          '${order.customerName} · ${order.title} · $formattedRemaining',
          '${order.customerName} · ${order.title} · $formattedRemaining',
        ),
        headerIcon: Icons.payments_outlined,
        headerColor: colors.income,
        bottomBar: FormSubmitButton(
          label: context.tr('Зачислить оплату', 'Save payment'),
          accentColor: colors.income,
          isLoading: false,
          icon: Icons.check_rounded,
          onPressed: () async {
            final cents =
                FinancialCalculator.parseAmountToCents(amountCtrl.text);
            if (cents == null || cents <= 0) return;
            final orderProvider = context.read<OrderProvider>();
            final customerProvider = context.read<CustomerProvider>();
            final dashboardProvider = context.read<DashboardProvider>();
            Navigator.of(context, rootNavigator: true).pop();
            HapticFeedback.mediumImpact();
            const uuid = Uuid();
            await orderProvider.recordPayment(
                  orderId: order.id,
                  customerId: order.customerId,
                  amountCents: cents.clamp(0, remainingCents),
                  paymentId: uuid.v4(),
                  transactionId: uuid.v4(),
                  notes: notesCtrl.text.trim().isNotEmpty
                      ? notesCtrl.text.trim()
                      : null,
                );
            customerProvider.load(silent: true, force: true);
            dashboardProvider.reload();
          },
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          shrinkWrap: true,
          children: [
            SheetField(
              label: context.tr('СУММА ПЛАТЕЖА', 'PAYMENT AMOUNT'),
              required: true,
              trailingLabel: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  amountCtrl.text = remainingCents % 100 == 0
                      ? (remainingCents ~/ 100).toString()
                      : (remainingCents / 100).toStringAsFixed(2);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.income.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Весь остаток ($formattedRemaining)',
                        'Full balance ($formattedRemaining)'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.income,
                    ),
                  ),
                ),
              ),
              child: FormAmountField(
                controller: amountCtrl,
                accentColor: colors.income,
                prefix: '+',
                currency: currency,
                autofocus: true,
              ),
            ),
            const SizedBox(height: 16),
            SheetField(
              label: context.tr('ЗАМЕТКА К ПЛАТЕЖУ', 'PAYMENT NOTE'),
              child: FormTextField(
                controller: notesCtrl,
                prefixIcon: Icons.notes_rounded,
                hint: context.tr('Наличные, перевод на карту и т.д.',
                    'Cash, card transfer, etc.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _serverCount(DebtProvider p, DebtDirection d, String key, int fallback) {
    final v = p.countFor(d, key);
    return v >= 0 ? v : fallback;
  }

  List<_DebtEntry> _applyFilters(List<_DebtEntry> source) {
    final filtered = source.where((e) {
      final st = e.computedStatus;
      final matchesStatus = switch (_statusFilter) {
        _DebtFilter.all => true,
        _DebtFilter.active => !e.isFullyPaid,
        _DebtFilter.overdue => st == DebtStatus.overdue,
        _DebtFilter.paid => e.isFullyPaid,
      };
      if (!matchesStatus) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = e.personName.toLowerCase().contains(q);
        final descMatch = e.description?.toLowerCase().contains(q) ?? false;
        if (!nameMatch && !descMatch) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.isFullyPaid != b.isFullyPaid) {
        return a.isFullyPaid ? 1 : -1;
      }
      final aOverdue = a.computedStatus == DebtStatus.overdue;
      final bOverdue = b.computedStatus == DebtStatus.overdue;
      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<DebtProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    final unpaidOrderEntries = orderProvider.allOrders
        .where((o) => o.status != OrderStatus.cancelled && o.remainingCents > 0)
        .map(_DebtEntry.order)
        .toList();

    final standaloneReceivables =
        provider.receivables.map(_DebtEntry.debt).toList();
    final allPayableEntries = provider.payables.map(_DebtEntry.debt).toList();

    final int receivableStandaloneCount = _serverCount(
      provider,
      DebtDirection.receivable,
      'all',
      standaloneReceivables.length,
    );
    final int receivableTotalCount =
        receivableStandaloneCount + unpaidOrderEntries.length;
    final int payableTotalCount = _serverCount(
      provider,
      DebtDirection.payable,
      'all',
      allPayableEntries.length,
    );

    final List<_DebtEntry> directionEntries;
    if (_direction == DebtDirection.receivable) {
      directionEntries = switch (_sourceFilter) {
        _DebtSourceFilter.all => [
            ...unpaidOrderEntries,
            ...standaloneReceivables,
          ],
        _DebtSourceFilter.orders => unpaidOrderEntries,
        _DebtSourceFilter.other => standaloneReceivables,
      };
    } else {
      directionEntries = allPayableEntries;
    }

    final visibleEntries = _applyFilters(directionEntries);
    final bool hasActiveFilter = _searchQuery.isNotEmpty ||
        _statusFilter != _DebtFilter.all ||
        (_direction == DebtDirection.receivable &&
            _sourceFilter != _DebtSourceFilter.all);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Pinned Top Bar (Back, Title, Search, + Новый) ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                0,
              ),
              child: _DebtsTopBar(
                totalCount: receivableTotalCount + payableTotalCount,
                searchActive: _searchActive,
                searchController: _searchCtrl,
                onBack: () {
                  HapticFeedback.selectionClick();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/profile');
                  }
                },
                onToggleSearch: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _searchActive = !_searchActive;
                    if (!_searchActive) {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    }
                  });
                },
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onAddDebt: () => _openForm(
                  '/profile/debts/new?direction=${_direction == DebtDirection.payable ? 'payable' : 'receivable'}',
                ),
              ),
            ),

            // ── 2. Pinned Segmented Direction Bar (Мне должны / Я должен) ─
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                0,
              ),
              child: _DirectionSegmentedBar(
                selected: _direction,
                receivableCount: receivableTotalCount,
                payableCount: payableTotalCount,
                onChanged: (dir) {
                  HapticFeedback.selectionClick();
                  context.read<DebtProvider>().setSelectedDirection(dir);
                  setState(() {
                    _direction = dir;
                    _statusFilter = _DebtFilter.all;
                    _sourceFilter = _DebtSourceFilter.all;
                  });
                },
              ),
            ),

            // ── 3. Compact Source Category Bar (Все / Заказы / Прочие) ────
            if (_direction == DebtDirection.receivable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kPagePadding,
                  AppSpacing.sm,
                  _kPagePadding,
                  0,
                ),
                child: _DebtSourceStrip(
                  selected: _sourceFilter,
                  allCount: receivableTotalCount,
                  ordersCount: unpaidOrderEntries.length,
                  otherCount: receivableStandaloneCount,
                  onSelect: (f) {
                    HapticFeedback.selectionClick();
                    setState(() => _sourceFilter = f);
                  },
                ),
              ),

            // ── 4. Pinned Status Filter Strip ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.sm,
                0,
                AppSpacing.xs,
              ),
              child: _DebtStatusFilterStrip(
                sourceEntries: directionEntries,
                serverCounts: (_direction == DebtDirection.payable ||
                        _sourceFilter == _DebtSourceFilter.other)
                    ? {
                        for (final f in _DebtFilter.values)
                          f: provider.countFor(_direction, f.name),
                      }
                    : const {},
                selected: _statusFilter,
                isReceivable: _direction == DebtDirection.receivable,
                onSelect: (f) {
                  HapticFeedback.selectionClick();
                  setState(() => _statusFilter = f);
                },
              ),
            ),

            // ── 4. Scrollable Debts List ──────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                child: provider.isLoading
                    ? const Align(
                        key: ValueKey('skeleton'),
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
                        key: const ValueKey('content'),
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
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [

              // ── 5. Debts List / Empty State ───────────────────────────────
              if (visibleEntries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kPagePadding,
                      vertical: AppSpacing.xl,
                    ),
                    child: AppEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: hasActiveFilter
                          ? context.tr('Записи не найдены', 'No records found')
                          : (_direction == DebtDirection.receivable
                              ? context.tr(
                                  'Никто вам не должен', 'Nobody owes you')
                              : context.tr(
                                  'Вы никому не должны', 'You owe nobody')),
                      subtitle: hasActiveFilter
                          ? context.tr(
                              'Попробуйте выбрать другой фильтр или изменить поисковый запрос',
                              'Try another filter or search query')
                          : (_direction == DebtDirection.receivable
                              ? context.tr(
                                  'Добавьте запись о средствах, которые должны вернуть вам',
                                  'Add a record of money owed to you')
                              : context.tr(
                                  'Добавьте запись о средствах, которые должны выплатить вы',
                                  'Add a record of money you owe')),
                      actionLabel: hasActiveFilter
                          ? context.tr('Сбросить фильтры', 'Reset filters')
                          : context.tr('Добавить долг', 'Add debt'),
                      onAction: () {
                        if (hasActiveFilter) {
                          setState(() {
                            _searchCtrl.clear();
                            _searchQuery = '';
                            _statusFilter = _DebtFilter.all;
                            _sourceFilter = _DebtSourceFilter.all;
                            _searchActive = false;
                          });
                        } else {
                          _openForm(
                            '/profile/debts/new?direction=${_direction == DebtDirection.payable ? 'payable' : 'receivable'}',
                          );
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entry = visibleEntries[i];
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ModernDebtCard(
                              entry: entry,
                              currency: currency,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                final op = context.read<OrderProvider>();
                                final dp = context.read<DebtProvider>();
                                final dash = context.read<DashboardProvider>();
                                if (entry.isOrder) {
                                  await context.push('/orders/${entry.id}');
                                  op.load(silent: true, force: true);
                                  dash.reload();
                                } else {
                                  await context.push('/profile/debts/${entry.id}');
                                  dp.load(force: true);
                                  dash.reload();
                                }
                              },
                              onPay: entry.isFullyPaid
                                  ? null
                                  : () {
                                      if (entry.isOrder) {
                                        _showOrderPaymentSheet(
                                            context, entry.order!);
                                      } else {
                                        _showPaymentSheet(
                                            context, entry.debt!);
                                      }
                                    },
                              onEdit: () => entry.isOrder
                                  ? _openForm('/orders/${entry.id}/edit')
                                  : _openForm('/profile/debts/${entry.id}/edit'),
                              onDelete: entry.isOrder
                                  ? null
                                  : () => _confirmDelete(context, entry.debt!),
                            ),
                          ),
                        );
                      },
                      childCount: visibleEntries.length,
                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 1. Top Bar ───────────────────────────────────────────────────────────────

class _DebtsTopBar extends StatelessWidget {
  const _DebtsTopBar({
    required this.totalCount,
    required this.searchActive,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onAddDebt,
  });

  final int totalCount;
  final bool searchActive;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddDebt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: searchActive
          ? Container(
              key: const ValueKey('debts-search'),
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
                        hintText: context.tr('Поиск по имени или описанию...',
                            'Search by name or description...'),
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
              key: const ValueKey('debts-title'),
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
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr('Долги', 'Debts'),
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
                      if (totalCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(10),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggleSearch,
                  child: Container(
                    width: 38,
                    height: 38,
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAddDebt,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 17, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Новый', 'New'),
                          style: const TextStyle(
                            fontSize: 12,
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

// ─── 2. Segmented Direction Bar ──────────────────────────────────────────────

class _DirectionSegmentedBar extends StatelessWidget {
  const _DirectionSegmentedBar({
    required this.selected,
    required this.receivableCount,
    required this.payableCount,
    required this.onChanged,
  });

  final DebtDirection selected;
  final int receivableCount;
  final int payableCount;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isReceivable = selected == DebtDirection.receivable;
    final pillColor = isReceivable ? colors.income : colors.expense;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment:
                isReceivable ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: pillColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _DirectionTabItem(
                label: context.tr('Мне должны', 'Owed to me'),
                icon: Icons.south_west_rounded,
                count: receivableCount,
                selected: isReceivable,
                activeColor: colors.income,
                onTap: () => onChanged(DebtDirection.receivable),
              ),
              _DirectionTabItem(
                label: context.tr('Я должен', 'I owe'),
                icon: Icons.north_east_rounded,
                count: payableCount,
                selected: !isReceivable,
                activeColor: colors.expense,
                onTap: () => onChanged(DebtDirection.payable),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionTabItem extends StatelessWidget {
  const _DirectionTabItem({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : colors.textPrimary,
                ),
                child: Text(label),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.24)
                      : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : colors.textSecondary,
                  ),
                  child: Text('$count'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 3. Compact Source Category Strip ────────────────────────────────────────

class _DebtSourceStrip extends StatelessWidget {
  const _DebtSourceStrip({
    required this.selected,
    required this.allCount,
    required this.ordersCount,
    required this.otherCount,
    required this.onSelect,
  });

  final _DebtSourceFilter selected;
  final int allCount;
  final int ordersCount;
  final int otherCount;
  final ValueChanged<_DebtSourceFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final items = <({
      _DebtSourceFilter filter,
      String label,
      int count,
      IconData icon,
    })>[
      (
        filter: _DebtSourceFilter.all,
        label: context.tr('Все', 'All'),
        count: allCount,
        icon: Icons.layers_outlined,
      ),
      (
        filter: _DebtSourceFilter.orders,
        label: context.tr('Заказы', 'Orders'),
        count: ordersCount,
        icon: Icons.receipt_long_outlined,
      ),
      (
        filter: _DebtSourceFilter.other,
        label: context.tr('Прочие', 'Other'),
        count: otherCount,
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(items[i].filter),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: selected == items[i].filter
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected == items[i].filter
                        ? colors.primary
                        : colors.border,
                    width: selected == items[i].filter ? 1.4 : 1.0,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 13,
                          color: selected == items[i].filter
                              ? colors.primary
                              : colors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected == items[i].filter
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: selected == items[i].filter
                                ? colors.primary
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${items[i].count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: selected == items[i].filter
                                ? colors.primary
                                : colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 4. Status Filter Strip ──────────────────────────────────────────────────

class _DebtStatusFilterStrip extends StatelessWidget {
  const _DebtStatusFilterStrip({
    required this.sourceEntries,
    required this.serverCounts,
    required this.selected,
    required this.isReceivable,
    required this.onSelect,
  });

  final List<_DebtEntry> sourceEntries;
  final Map<_DebtFilter, int> serverCounts;
  final _DebtFilter selected;
  final bool isReceivable;
  final ValueChanged<_DebtFilter> onSelect;

  int _countFor(_DebtFilter filter) {
    final server = serverCounts[filter] ?? -1;
    if (server >= 0) return server;
    return sourceEntries.where((e) {
      return switch (filter) {
        _DebtFilter.all => true,
        _DebtFilter.active => !e.isFullyPaid,
        _DebtFilter.overdue => e.computedStatus == DebtStatus.overdue,
        _DebtFilter.paid => e.isFullyPaid,
      };
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final items = <({
      _DebtFilter filter,
      String label,
      Color activeColor,
    })>[
      (
        filter: _DebtFilter.all,
        label: context.tr('Все', 'All'),
        activeColor: colors.primary,
      ),
      (
        filter: _DebtFilter.active,
        label: context.tr('Активные', 'Active'),
        activeColor: isReceivable ? colors.income : const Color(0xFFD97706),
      ),
      (
        filter: _DebtFilter.overdue,
        label: context.tr('Просроченные', 'Overdue'),
        activeColor: colors.expense,
      ),
      (
        filter: _DebtFilter.paid,
        label: context.tr('Погашенные', 'Paid'),
        activeColor: const Color(0xFF475569),
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          final isSelected = selected == item.filter;
          final count = _countFor(item.filter);

          return GestureDetector(
            onTap: () => onSelect(item.filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? item.activeColor : colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? item.activeColor : colors.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: item.activeColor.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSelected) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.activeColor,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.24)
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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

// ─── 4. Balanced Medium-Minimalist Debt Card with Inline Actions ─────────────

class _ModernDebtCard extends StatelessWidget {
  const _ModernDebtCard({
    required this.entry,
    required this.currency,
    required this.onTap,
    required this.onPay,
    required this.onEdit,
    this.onDelete,
  });

  final _DebtEntry entry;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onPay;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isReceivable =
        entry.isOrder || entry.debt!.direction == DebtDirection.receivable;
    final status = entry.computedStatus;
    final isPaid = entry.isFullyPaid;
    final isOverdue = status == DebtStatus.overdue;

    final progress = entry.originalAmountCents > 0
        ? (entry.paidAmountCents / entry.originalAmountCents).clamp(0.0, 1.0)
        : 0.0;

    final avatarColor = isPaid
        ? colors.income
        : (isOverdue
            ? colors.expense
            : (isReceivable ? colors.primary : const Color(0xFFE11D48)));

    final barColor = isPaid
        ? colors.income
        : (isOverdue ? colors.expense : colors.primary);

    // Subtitle combines description and due date cleanly on 1 line
    final subtitleParts = <String>[
      if (entry.description != null && entry.description!.trim().isNotEmpty)
        entry.description!.trim(),
      if (!isPaid && entry.dueDate != null)
        context.tr('до ${DateHelper.formatShortDate(entry.dueDate!)}',
            'due ${DateHelper.formatShortDate(entry.dueDate!)}'),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // ── Row 1: Avatar + Name/Subtitle + Amount & Status Badge ──────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    entry.personName.trim().isNotEmpty
                        ? entry.personName.trim()[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.personName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (entry.isOrder) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.tr('Заказ', 'Order'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isOverdue ? FontWeight.w600 : FontWeight.w500,
                            color: isOverdue
                                ? colors.expense
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FinancialCalculator.formatCents(
                        isPaid
                            ? entry.originalAmountCents
                            : entry.remainingCents,
                        currency: currency,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isOverdue ? colors.expense : colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppStatusBadge.debt(status, context),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Row 2: Slim Progress Bar ───────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),

            const SizedBox(height: 8),

            // ── Row 3: Paid Caption + Inline Action Buttons ────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPaid
                        ? context.tr('Погашен полностью', 'Fully paid')
                        : context.tr(
                            'Выплачено: ${FinancialCalculator.formatCents(entry.paidAmountCents, currency: currency)}',
                            'Paid: ${FinancialCalculator.formatCents(entry.paidAmountCents, currency: currency)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? colors.income : colors.textSecondary,
                    ),
                  ),
                ),
                if (onPay != null) ...[
                  GestureDetector(
                    onTap: onPay,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isReceivable ? colors.income : colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isReceivable
                                ? context.tr('Принять', 'Collect')
                                : context.tr('Погасить', 'Pay'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                _CardIconBtn(
                  icon: Icons.edit_outlined,
                  color: colors.textSecondary,
                  bgColor: colors.surfaceSecondary,
                  onTap: onEdit,
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  _CardIconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: colors.expense,
                    bgColor: colors.expenseBackground,
                    onTap: onDelete!,
                  ),
                ],
              ],
            ),
          ],
        ),
      );
  }
}

class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
