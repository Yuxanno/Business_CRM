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
  bool _statusChanging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<OrderProvider>();
    final order = await provider.getById(widget.orderId);
    final payments = await provider.getPaymentsForOrder(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _payments = payments;
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(OrderStatus newStatus) async {
    if (_order == null || _order!.status == newStatus) return;
    if (newStatus == OrderStatus.cancelled) {
      final confirm = await showConfirmSheet(
        context: context,
        title: 'Отменить заказ?',
        message: 'История платежей будет сохранена.',
        confirmLabel: 'Отменить заказ',
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => _statusChanging = true);
    final updated = _order!.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    final provider = context.read<OrderProvider>();
    await provider.update(updated);
    HapticFeedback.lightImpact();
    await _load();
    if (mounted) setState(() => _statusChanging = false);
  }

  Future<void> _delete(BuildContext context) async {
    final op = context.read<OrderProvider>();
    final router = GoRouter.of(context);
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить заказ?',
      message: 'Это действие нельзя отменить.',
    );
    if (confirm == true && mounted) {
      await op.delete(widget.orderId);
      router.go('/orders');
    }
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
        appBar: AppBar(backgroundColor: colors.background, elevation: 0),
        body: Center(
          child: Text('Заказ не найден',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  // Back button — round icon, no label
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/orders');
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20, color: colors.textPrimary),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Edit — outlined pill
                  _NavAction(
                    label: 'Изменить',
                    icon: Icons.edit_outlined,
                    onTap: () =>
                        context.push('/orders/${order.id}/edit'),
                    colors: colors,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Delete — danger tint pill
                  _NavAction(
                    label: 'Удалить',
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _delete(context),
                    colors: colors,
                    danger: true,
                  ),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
                children: [
            // ── Title block ───────────────────────────────────────
            Text(
              order.title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.15,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Клиент: ${order.customerName}',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Amount label + value
            Text(
              order.isFullyPaid ? 'Оплачено' : 'Осталось получить',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              FinancialCalculator.formatCents(
                order.isFullyPaid
                    ? order.totalPriceCents
                    : order.remainingCents,
                currency: currency,
              ),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: order.isFullyPaid ? colors.income : colors.warning,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Status selector ───────────────────────────────────
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Статус',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _StatusDropdown(
                          current: order.status,
                          isChanging: _statusChanging,
                          onChanged: _changeStatus,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Description / dates card ──────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.description != null &&
                      order.description!.isNotEmpty) ...[
                    Text(
                      order.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    Divider(color: colors.divider, height: AppSpacing.xl),
                  ],
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Создан',
                    value: DateHelper.formatDate(order.createdAt),
                  ),
                  if (order.dueDate != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      icon: Icons.flag_outlined,
                      label: 'Дедлайн',
                      value: DateHelper.formatDate(order.dueDate!),
                      valueColor: _isOverdue(order)
                          ? colors.expense
                          : colors.warning,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Financial summary card ────────────────────────────
            AppCard(
              child: Column(
                children: [
                  _FinRow(
                    label: 'Стоимость заказа',
                    value: FinancialCalculator.formatCents(
                        order.totalPriceCents,
                        currency: currency),
                    color: colors.textPrimary,
                    bold: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FinRow(
                    label: 'Получено',
                    value: FinancialCalculator.formatCents(
                        order.receivedCents,
                        currency: currency),
                    color: colors.income,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(color: colors.divider, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  _FinRow(
                    label: 'Остаток',
                    value: FinancialCalculator.formatCents(
                        order.remainingCents,
                        currency: currency),
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
                        order.isFullyPaid
                            ? colors.income
                            : colors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // ── Record payment button ─────────────────────────────
            if (!order.isFullyPaid &&
                order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Записать платёж',
                onPressed: () => _showPaymentSheet(context),
                icon: Icons.add_rounded,
              ),
            ],

            // ── Payment history ───────────────────────────────────
            if (_payments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'История платежей',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._payments.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateHelper.formatDate(p.paidAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (p.notes != null)
                                Text(
                                  p.notes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textMuted,
                                  ),
                                ),
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
                ),
              ),
            ],

            const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(Order order) {
    if (order.dueDate == null) return false;
    return order.dueDate!.isBefore(DateTime.now()) &&
        order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled;
  }
}

// ─── Nav Action Button ────────────────────────────────────────────────────────

class _NavAction extends StatelessWidget {
  const _NavAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AppSemanticColors colors;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final textColor = danger ? colors.expense : colors.textSecondary;
    final bgColor = danger
        ? colors.expenseBackground
        : colors.surface;
    final borderColor = danger ? colors.expense.withValues(alpha: 0.35) : colors.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.current,
    required this.onChanged,
    this.isChanging = false,
  });

  final OrderStatus current;
  final Future<void> Function(OrderStatus) onChanged;
  final bool isChanging;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return isChanging
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          )
        : DropdownButton<OrderStatus>(
            value: current,
            underline: const SizedBox.shrink(),
            isDense: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary, size: 20),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _statusColor(current, colors),
            ),
            dropdownColor: colors.surface,
            items: OrderStatus.values.map((s) {
              return DropdownMenuItem(
                value: s,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor(s, colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusLabel(s),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (s) {
              if (s != null) onChanged(s);
            },
          );
  }

  Color _statusColor(OrderStatus status, AppSemanticColors colors) =>
      switch (status) {
        OrderStatus.newOrder => colors.primary,
        OrderStatus.inProgress => const Color(0xFF3B82F6),
        OrderStatus.completed => colors.income,
        OrderStatus.cancelled => colors.textMuted,
      };

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.newOrder => 'Новый',
        OrderStatus.inProgress => 'В работе',
        OrderStatus.completed => 'Завершён',
        OrderStatus.cancelled => 'Отменён',
      };
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.textMuted),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Financial Row ────────────────────────────────────────────────────────────

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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
