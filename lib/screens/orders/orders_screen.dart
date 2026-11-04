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
import '../../components/app_search_bar.dart';
import '../../components/app_chip.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();

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
      appBar: AppBar(
        title: const Text('Заказы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/orders/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
            child: AppSearchBar(
              hint: 'Поиск заказов...',
              controller: _searchCtrl,
              onChanged: provider.setSearch,
              onClear: () {
                _searchCtrl.clear();
                provider.setSearch('');
              },
            ),
          ),
          // Status filters
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              scrollDirection: Axis.horizontal,
              children: [
                AppFilterChip(
                  label: 'Все',
                  selected: provider.statusFilter == null,
                  onTap: () => provider.setStatusFilter(null),
                ),
                const SizedBox(width: AppSpacing.sm),
                ...OrderStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppFilterChip(
                        label: _statusLabel(s),
                        selected: provider.statusFilter == s,
                        onTap: () => provider.setStatusFilter(s),
                      ),
                    )),
              ],
            ),
          ),
          // List
          Expanded(
            child: provider.isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : provider.orders.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Заказов нет',
                        subtitle: 'Нажмите + чтобы создать первый заказ',
                        actionLabel: 'Создать заказ',
                        onAction: () => context.go('/orders/new'),
                      )
                    : RefreshIndicator(
                        color: colors.primary,
                        onRefresh: () => context.read<OrderProvider>().load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.md,
                              AppSpacing.xl,
                              80),
                          itemCount: provider.orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) {
                            final order = provider.orders[i];
                            return _OrderCard(
                              order: order,
                              currency: currency,
                              onTap: () =>
                                  context.go('/orders/${order.id}'),
                              onDelete: () =>
                                  _confirmDelete(context, order),
                              onEdit: () =>
                                  context.go('/orders/${order.id}/edit'),
                            );
                          },
                        ),
                      ),
          ),
        ],
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
      message: 'Это действие нельзя отменить. История платежей по заказу будет удалена.',
    );
    if (confirm == true && mounted) {
      await context.read<OrderProvider>().delete(order.id);
    }
  }
}

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

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Изменить',
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: colors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Удалить',
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppStatusBadge.order(order.status, context),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.customerName,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            // Payment progress
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: order.paymentProgress.clamp(0.0, 1.0),
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation(
                  order.isFullyPaid ? colors.income : colors.primary,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Получено: ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted),
                  ),
                ),
                Text(
                  FinancialCalculator.formatCents(order.totalPriceCents,
                      currency: currency),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            if (order.dueDate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 11, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    DateHelper.formatDate(order.dueDate!),
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
