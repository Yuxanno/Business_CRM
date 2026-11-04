import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  List<OrderPayment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<OrderProvider>();
    final order = await provider.getById(widget.orderId);
    final payments = await provider.getPaymentsForOrder(widget.orderId);
    setState(() {
      _order = order;
      _payments = payments;
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

    if (_order == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: Center(
          child: Text('Заказ не найден',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Заказ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () =>
                context.go('/orders/${order.id}/edit'),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: colors.expense),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Status + title
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(order.title,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                    ),
                    AppStatusBadge.order(order.status, context),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(order.customerName,
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary)),
                if (order.description != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(order.description!,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                          height: 1.5)),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: colors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                        'Создан: ${DateHelper.formatDate(order.createdAt)}',
                        style: TextStyle(
                            fontSize: 12, color: colors.textMuted)),
                    if (order.dueDate != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      Icon(Icons.flag_outlined,
                          size: 13, color: colors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                          'Дедлайн: ${DateHelper.formatDate(order.dueDate!)}',
                          style: TextStyle(
                              fontSize: 12, color: colors.textMuted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Financial summary
          AppCard(
            child: Column(
              children: [
                _FinRow(
                  label: 'Стоимость заказа',
                  value: FinancialCalculator.formatCents(
                      order.totalPriceCents, currency: currency),
                  color: colors.textPrimary,
                  bold: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FinRow(
                  label: 'Получено',
                  value: FinancialCalculator.formatCents(
                      order.receivedCents, currency: currency),
                  color: colors.income,
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.divider),
                const SizedBox(height: AppSpacing.sm),
                _FinRow(
                  label: 'Остаток',
                  value: FinancialCalculator.formatCents(
                      order.remainingCents, currency: currency),
                  color: order.isFullyPaid
                      ? colors.income
                      : colors.warning,
                  bold: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: order.paymentProgress.clamp(0.0, 1.0),
                    backgroundColor: colors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation(
                      order.isFullyPaid ? colors.income : colors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Record payment button
          if (!order.isFullyPaid &&
              order.status != OrderStatus.cancelled)
            AppButton(
              label: 'Записать платёж',
              onPressed: () => _showPaymentSheet(context),
              icon: Icons.add_rounded,
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Payment history
          if (_payments.isNotEmpty) ...[
            Text('История платежей',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            ..._payments.map((p) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.incomeBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.payment_rounded,
                              color: colors.income, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                  DateHelper.formatDate(p.paidAt),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textPrimary)),
                              if (p.notes != null)
                                Text(p.notes!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textMuted)),
                            ],
                          ),
                        ),
                        Text(
                          '+${FinancialCalculator.formatCents(p.amountCents, currency: currency)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          // Status actions
          const SizedBox(height: AppSpacing.xxl),
          _StatusActions(order: order, onChanged: _load),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    final colors = context.appColors;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final currency = context.read<SettingsProvider>().currency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Записать платёж',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
                'Остаток: ${FinancialCalculator.formatCents(_order!.remainingCents, currency: currency)}',
                style:
                    TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(labelText: 'Сумма'),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: notesCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration:
                  const InputDecoration(labelText: 'Заметка (необязательно)'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Подтвердить',
              onPressed: () async {
                final cents =
                    FinancialCalculator.parseAmountToCents(amountCtrl.text);
                if (cents == null || cents <= 0) return;
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                const uuid = Uuid();
                await context.read<OrderProvider>().recordPayment(
                      orderId: _order!.id,
                      customerId: _order!.customerId,
                      amountCents:
                          cents.clamp(0, _order!.remainingCents),
                      paymentId: uuid.v4(),
                      transactionId: uuid.v4(),
                      notes: notesCtrl.text.trim().isNotEmpty
                          ? notesCtrl.text.trim()
                          : null,
                    );
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить заказ?',
      message: 'Это действие нельзя отменить.',
    );
    if (confirm == true && mounted) {
      await context.read<OrderProvider>().delete(widget.orderId);
      context.go('/orders');
    }
  }
}

class _FinRow extends StatelessWidget {
  const _FinRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                fontWeight:
                    bold ? FontWeight.w500 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            )),
      ],
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({required this.order, required this.onChanged});
  final Order order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.status == OrderStatus.newOrder)
          AppButton(
            label: 'Взять в работу',
            onPressed: () => _changeStatus(
                context, order, OrderStatus.inProgress),
            variant: AppButtonVariant.secondary,
            icon: Icons.play_arrow_rounded,
          ),
        if (order.status == OrderStatus.inProgress) ...[
          AppButton(
            label: 'Завершить заказ',
            onPressed: () =>
                _changeStatus(context, order, OrderStatus.completed),
            variant: AppButtonVariant.secondary,
            icon: Icons.check_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (order.status != OrderStatus.completed) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Отменить заказ',
            onPressed: () => _cancelOrder(context, order),
            variant: AppButtonVariant.text,
          ),
        ],
      ],
    );
  }

  Future<void> _changeStatus(
      BuildContext context, Order order, OrderStatus status) async {
    final updated = order.copyWith(
        status: status, updatedAt: DateTime.now());
    await context.read<OrderProvider>().update(updated);
    onChanged();
  }

  Future<void> _cancelOrder(
      BuildContext context, Order order) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Отменить заказ?',
      message: 'История платежей будет сохранена.',
      confirmLabel: 'Отменить заказ',
    );
    if (confirm == true) {
      await _changeStatus(context, order, OrderStatus.cancelled);
    }
  }
}
