import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';

const double _kPagePadding = 20.0;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    HapticFeedback.mediumImpact();
    await context.read<OrderProvider>().load(force: true);
    if (mounted) {
      context.read<CustomerProvider>().load(silent: true, force: true);
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _openForm(String route) async {
    HapticFeedback.lightImpact();
    await context.push(route);
    if (mounted) {
      context.read<CustomerProvider>().load(silent: true, force: true);
      context.read<DashboardProvider>().reload();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Order order) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить заказ?', 'Delete order?'),
      message: context.tr(
        'Заказ «${order.title}» и история его платежей будут удалены безвозвратно.',
        'Order "${order.title}" and its payment history will be permanently deleted.',
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<OrderProvider>().delete(order.id);
      if (context.mounted) {
        context.read<CustomerProvider>().load(silent: true);
        context.read<DashboardProvider>().reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<OrderProvider>();
    final currency = context.watch<SettingsProvider>().currency;
    final allOrders = provider.allOrders;
    final visibleOrders = provider.orders;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Pinned Top Header / Search Bar ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.md,
                _kPagePadding,
                0,
              ),
              child: _OrdersTopBar(
                totalCount: provider.totalCount,
                searchActive: _searchActive,
                searchController: _searchCtrl,
                onToggleSearch: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _searchActive = !_searchActive;
                    if (!_searchActive) {
                      _searchCtrl.clear();
                      provider.setSearch('');
                    }
                  });
                },
                onSearchChanged: provider.setSearch,
                onAddOrder: () => _openForm('/orders/new'),
              ),
            ),

            // ── 2. Pinned Status Filter Strip with Counts ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.md,
                0,
                AppSpacing.xs,
              ),
              child: _StatusFilterStrip(
                allOrders: allOrders,
                totalCount: provider.totalCount,
                countForStatus: provider.countForStatus,
                selected: provider.statusFilter,
                onSelect: (status) {
                  HapticFeedback.selectionClick();
                  provider.setStatusFilter(status);
                },
              ),
            ),

            // ── 3. Scrollable Orders List ─────────────────────────────────
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

              // ── 4. Orders List / Empty State ──────────────────────────────
              if (visibleOrders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kPagePadding,
                      vertical: AppSpacing.xl,
                    ),
                    child: AppEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: allOrders.isEmpty
                          ? context.tr('Пока нет заказов', 'No orders yet')
                          : context.tr('Заказы не найдены', 'No orders found'),
                      subtitle: allOrders.isEmpty
                          ? context.tr(
                              'Создайте первый заказ, чтобы отслеживать сроки, статусы и платежи клиентов',
                              'Create your first order to track deadlines, statuses, and customer payments',
                            )
                          : context.tr(
                              'Попробуйте выбрать другой статус или изменить поисковый запрос',
                              'Try choosing another status or changing your search query',
                            ),
                      actionLabel: allOrders.isEmpty
                          ? context.tr('Создать заказ', 'Create order')
                          : context.tr('Сбросить фильтры', 'Reset filters'),
                      onAction: () {
                        if (allOrders.isEmpty) {
                          _openForm('/orders/new');
                        } else {
                          _searchCtrl.clear();
                          provider.setSearch('');
                          provider.setStatusFilter(null);
                          setState(() => _searchActive = false);
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
                        final order = visibleOrders[i];
                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ModernOrderCard(
                              order: order,
                              currency: currency,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                await context.push('/orders/${order.id}');
                                if (mounted) {
                                  context.read<OrderProvider>().load();
                                  context.read<CustomerProvider>().load(silent: true);
                                  context.read<DashboardProvider>().reload();
                                }
                              },
                              onEdit: () =>
                                  _openForm('/orders/${order.id}/edit'),
                              onDelete: () => _confirmDelete(context, order),
                            ),
                          ),
                        );
                      },
                      childCount: visibleOrders.length,
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

class _OrdersTopBar extends StatelessWidget {
  const _OrdersTopBar({
    required this.totalCount,
    required this.searchActive,
    required this.searchController,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onAddOrder,
  });

  final int totalCount;
  final bool searchActive;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: searchActive
          ? Container(
              key: const ValueKey('orders-search'),
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
                          'Поиск по названию или клиенту...',
                          'Search by title or customer...',
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
              key: const ValueKey('orders-title'),
              children: [
                Text(
                  context.tr('Заказы', 'Orders'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
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
                  onTap: onAddOrder,
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
                          style: TextStyle(
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

// ─── 2. Status Filter Strip ──────────────────────────────────────────────────

class _StatusFilterStrip extends StatelessWidget {
  const _StatusFilterStrip({
    required this.allOrders,
    required this.totalCount,
    required this.countForStatus,
    required this.selected,
    required this.onSelect,
  });

  final List<Order> allOrders;
  final int totalCount;
  final int Function(OrderStatus) countForStatus;
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  int _countFor(OrderStatus status) => countForStatus(status);


  @override
  Widget build(BuildContext context) {
    final items = <(OrderStatus?, String, Color?)>[
      (null, context.tr('Все', 'All'), null),
      (OrderStatus.newOrder, context.tr('Новые', 'New'), AppColors.primary),
      (
        OrderStatus.inProgress,
        context.tr('В работе', 'In progress'),
        const Color(0xFF0EA5E9),
      ),
      (
        OrderStatus.completed,
        context.tr('Завершённые', 'Completed'),
        AppColors.income,
      ),
      (
        OrderStatus.cancelled,
        context.tr('Отменённые', 'Cancelled'),
        AppColors.slate400,
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = selected == item.$1;
          final count =
              item.$1 == null ? totalCount : _countFor(item.$1!);
          final colors = context.appColors;
          final activeColor = item.$3 ?? colors.primary;

          return GestureDetector(
            onTap: () => onSelect(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? activeColor : colors.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : colors.textMuted,
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

// ─── 4. Modern Order Card ────────────────────────────────────────────────────

class _ModernOrderCard extends StatelessWidget {
  const _ModernOrderCard({
    required this.order,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Order order;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = order.paymentProgress.clamp(0.0, 1.0);
    final isCancelled = order.status == OrderStatus.cancelled;
    final paidColor = isCancelled
        ? colors.textMuted
        : (order.isFullyPaid ? colors.income : colors.primary);

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: AppRadius.cardLarge,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Customer Avatar + Title + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppAvatar(
                name: order.customerName.isNotEmpty
                    ? order.customerName
                    : order.title,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.customerName,
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
              const SizedBox(width: 8),
              AppStatusBadge.order(order.status, context),
            ],
          ),

          const SizedBox(height: 14),

          // Financial & Deadline Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Стоимость заказа', 'Order total'),
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
                            child: Text(
                              FinancialCalculator.formatCents(
                                order.totalPriceCents,
                                currency: currency,
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.dueDate != null)
                      _DeadlineBadge(
                        dueDate: order.dueDate!,
                        isDone: order.status == OrderStatus.completed ||
                            order.status == OrderStatus.cancelled,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: colors.border.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation(paidColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      order.isFullyPaid
                          ? Icons.verified_rounded
                          : Icons.payments_outlined,
                      size: 13,
                      color: order.isFullyPaid
                          ? colors.income
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: order.isFullyPaid
                                  ? context.tr(
                                      'Оплачено полностью', 'Fully paid')
                                  : context.tr(
                                      'Получено: ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}',
                                      'Paid: ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}',
                                    ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: order.isFullyPaid
                                    ? colors.income
                                    : colors.textSecondary,
                              ),
                            ),
                            if (!order.isFullyPaid && !isCancelled) ...[
                              TextSpan(
                                text: '  •  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                              TextSpan(
                                text: context.tr(
                                  'Остаток: ${FinancialCalculator.formatCentsCompact(order.remainingCents, currency: currency)}',
                                  'Due: ${FinancialCalculator.formatCentsCompact(order.remainingCents, currency: currency)}',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.warning,
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OrderCardIconAction(
                      icon: Icons.edit_outlined,
                      color: colors.textSecondary,
                      bgColor: colors.surface,
                      borderColor: colors.border,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 6),
                    _OrderCardIconAction(
                      icon: Icons.delete_outline_rounded,
                      color: colors.expense,
                      bgColor: colors.surface,
                      borderColor: colors.border,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCardIconAction extends StatelessWidget {
  const _OrderCardIconAction({
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

class _DeadlineBadge extends StatelessWidget {
  const _DeadlineBadge({
    required this.dueDate,
    required this.isDone,
  });

  final DateTime dueDate;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diffDays = target.difference(today).inDays;

    Color badgeColor = colors.textSecondary;
    String label = context.tr(
      'до ${DateHelper.formatShortDate(dueDate)}',
      'due ${DateHelper.formatShortDate(dueDate)}',
    );
    IconData icon = Icons.event_outlined;

    if (!isDone) {
      if (diffDays < 0) {
        badgeColor = colors.expense;
        label = context.tr('Просрочен', 'Overdue');
        icon = Icons.warning_amber_rounded;
      } else if (diffDays == 0) {
        badgeColor = colors.warning;
        label = context.tr('Сдать сегодня', 'Due today');
        icon = Icons.schedule_rounded;
      } else if (diffDays == 1) {
        badgeColor = colors.warning;
        label = context.tr('Сдать завтра', 'Due tomorrow');
        icon = Icons.schedule_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
