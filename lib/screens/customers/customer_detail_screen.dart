import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../providers/customer_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customerProvider = context.read<CustomerProvider>();
    final orderProvider = context.read<OrderProvider>();

    final customer = await customerProvider.getById(widget.customerId);
    final orders =
        await orderProvider.getByCustomer(widget.customerId);

    setState(() {
      _customer = customer;
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (_customer == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: Center(
          child: Text('Клиент не найден',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final customer = _customer!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Клиент'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () =>
                context.go('/profile/customers/${customer.id}/edit'),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colors.expense),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // Profile header
            AppCard(
              child: Row(
                children: [
                  AppAvatar(name: customer.name, size: 56),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (customer.phone != null)
                          _ContactRow(
                            icon: Icons.phone_outlined,
                            text: customer.phone!,
                            onTap: () => HapticFeedback.lightImpact(),
                          ),
                        if (customer.email != null)
                          _ContactRow(
                            icon: Icons.email_outlined,
                            text: customer.email!,
                          ),
                        if (customer.phone == null && customer.email == null)
                          Text(
                            'Контакты не указаны',
                            style: TextStyle(
                                fontSize: 12, color: colors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Заказов',
                    value: '${customer.totalOrdersCount}',
                    icon: Icons.receipt_long_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Выручка',
                    value: FinancialCalculator.formatCentsCompact(
                        customer.totalOrdersAmountCents,
                        currency: currency),
                    icon: Icons.trending_up_rounded,
                    color: colors.income,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Долг',
                    value: FinancialCalculator.formatCentsCompact(
                        customer.outstandingBalanceCents,
                        currency: currency),
                    icon: Icons.account_balance_wallet_outlined,
                    color: customer.outstandingBalanceCents > 0
                        ? colors.warning
                        : colors.income,
                  ),
                ),
              ],
            ),
            if (customer.notes != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 16, color: colors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        customer.notes!,
                        style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Orders section
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Text(
                  'История заказов',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/orders/new'),
                  child: Text(
                    '+ Новый заказ',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_orders.isEmpty)
              AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Заказов нет',
                subtitle: 'Заказы этого клиента появятся здесь',
              )
            else
              ..._orders.map((order) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _OrderRow(
                      order: order,
                      currency: currency,
                      onTap: () => context.go('/orders/${order.id}'),
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить клиента?',
      message: 'Это действие нельзя отменить.',
    );
    if (confirm == true && mounted) {
      await context.read<CustomerProvider>().delete(widget.customerId);
      context.go('/profile/customers');
    }
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 13, color: colors.textMuted),
            const SizedBox(width: 4),
            Text(text,
                style:
                    TextStyle(fontSize: 13, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.currency,
    required this.onTap,
  });

  final Order order;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateHelper.formatDate(order.createdAt),
                  style:
                      TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusBadge.order(order.status, context),
              const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
