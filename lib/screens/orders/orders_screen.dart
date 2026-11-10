import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_chip.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<OrderProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header / Search ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _searchActive
                    ? _SearchField(
                        key: const ValueKey('search'),
                        controller: _searchCtrl,
                        onChanged: provider.setSearch,
                        onClose: () {
                          setState(() => _searchActive = false);
                          _searchCtrl.clear();
                          provider.setSearch('');
                        },
                      )
                    : Row(
                        key: const ValueKey('title'),
                        children: [
                          Expanded(
                            child: Text(
                              'Заказы',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _searchActive = true),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: colors.border),
                              ),
                              child: Icon(Icons.search_rounded,
                                  size: 18,
                                  color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Status filters ───────────────────────────────────────────────
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                scrollDirection: Axis.horizontal,
                children: [
                  AppFilterChip(
                    label: 'Все',
                    selected: provider.statusFilter == null,
                    onTap: () => provider.setStatusFilter(null),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ...OrderStatus.values.map((s) => Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppFilterChip(
                          label: _statusLabel(s),
                          selected: provider.statusFilter == s,
                          onTap: () => provider.setStatusFilter(s),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                      child: const AppSkeletonList(count: 5),
                    )
                  : provider.orders.isEmpty
                      ? AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Пока нет заказов',
                          subtitle:
                              'Создайте заказ — статус и оплату будет видно сразу',
                          actionLabel: 'Создать заказ',
                          onAction: () => context.push('/orders/new'),
                        )
                      : RefreshIndicator(
                          color: colors.primary,
                          onRefresh: () =>
                              context.read<OrderProvider>().load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.xs,
                                AppSpacing.xl,
                                100),
                            itemCount: provider.orders.length,
                            itemBuilder: (ctx, i) {
                              final order = provider.orders[i];
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _OrderCard(
                                  order: order,
                                  currency: currency,
                                  onTap: () =>
                                      context.go('/orders/${order.id}'),
                                  onDelete: () =>
                                      _confirmDelete(context, order),
                                  onEdit: () => context
                                      .push('/orders/${order.id}/edit'),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.newOrder => 'Новые',
        OrderStatus.inProgress => 'В работе',
        OrderStatus.completed => 'Завершённые',
        OrderStatus.cancelled => 'Отменённые',
      };

  Future<void> _confirmDelete(BuildContext context, Order order) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить заказ?',
      message:
          'Это действие нельзя отменить. История платежей будет удалена.',
    );
    if (confirm == true && mounted) {
      await context.read<OrderProvider>().delete(order.id);
    }
  }
}

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasText = widget.controller.text.isNotEmpty;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          // Back — closes search
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(Icons.arrow_back_rounded,
                size: 22, color: colors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          // Input
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              autofocus: true,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Поиск заказов…',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textMuted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
              ),
            ),
          ),
          // Clear
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                widget.onChanged('');
              },
              child: Padding(
                padding:
                    const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.close_rounded,
                    size: 18, color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Order card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.currency,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  final Order order;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = order.paymentProgress.clamp(0.0, 1.0);
    final paidColor =
        order.isFullyPaid ? colors.income : colors.primary;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.40,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Изменить',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: colors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Удалить',
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge.order(order.status, context),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Payment row ───────────────────────────────────────────────
            Row(
              children: [
                // Progress bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colors.surfaceSecondary,
                          valueColor:
                              AlwaysStoppedAnimation(paidColor),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.isFullyPaid
                            ? 'Оплачено полностью'
                            : 'Получено ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: order.isFullyPaid
                              ? colors.income
                              : colors.textMuted,
                          fontWeight: order.isFullyPaid
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FinancialCalculator.formatCents(
                          order.totalPriceCents,
                          currency: currency),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.3,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    if (order.dueDate != null)
                      Text(
                        _dueDateLabel(order.dueDate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isDueSoon(order.dueDate!)
                              ? colors.warning
                              : colors.textMuted,
                          fontWeight: _isDueSoon(order.dueDate!)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Status hint ───────────────────────────────────────────────
            if (order.status != OrderStatus.completed &&
                order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: AppSpacing.sm),
              _StatusHint(order: order),
            ],
          ],
        ),
      ),
    );
  }

  String _dueDateLabel(DateTime due) {
    final diff = due.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Просрочен';
    if (diff == 0) return 'Сдать сегодня';
    if (diff == 1) return 'Сдать завтра';
    return 'до ${DateHelper.formatShortDate(due)}';
  }

  bool _isDueSoon(DateTime due) {
    final diff = due.difference(DateTime.now()).inDays;
    return diff <= 1;
  }
}

// ─── Status hint strip ────────────────────────────────────────────────────────

class _StatusHint extends StatelessWidget {
  const _StatusHint({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final (text, color) = switch (order.status) {
      OrderStatus.newOrder => order.isFullyPaid
          ? ('Взять в работу', colors.primary)
          : ('Принять оплату → взять в работу', colors.primary),
      OrderStatus.inProgress => order.isFullyPaid
          ? ('Завершить заказ', colors.income)
          : ('Принять оплату → завершить', colors.income),
      _ => ('', colors.textMuted),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.arrow_forward_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
