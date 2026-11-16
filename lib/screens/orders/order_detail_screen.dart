import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/app_status_badge.dart';
import '../../components/form_widgets.dart';

const double _kPagePadding = 20.0;

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
    if (_order == null || _order!.status == newStatus || _statusChanging) {
      return;
    }
    HapticFeedback.selectionClick();
    if (newStatus == OrderStatus.cancelled) {
      final confirm = await showConfirmSheet(
        context: context,
        title: context.tr('Отменить заказ?', 'Cancel order?'),
        message: context.tr(
          'История платежей по этому заказу будет сохранена.',
          'Payment history for this order will be preserved.',
        ),
        confirmLabel: context.tr('Отменить заказ', 'Cancel order'),
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
    if (mounted) {
      context.read<DashboardProvider>().reload();
    }
    HapticFeedback.lightImpact();
    await _load();
    if (mounted) setState(() => _statusChanging = false);
  }

  Future<void> _editOrder() async {
    if (_order == null) return;
    HapticFeedback.selectionClick();
    await context.push('/orders/${_order!.id}/edit');
    if (mounted) {
      await _load();
      if (mounted) {
        context.read<DashboardProvider>().reload();
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final op = context.read<OrderProvider>();
    final dash = context.read<DashboardProvider>();
    final router = GoRouter.of(context);
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить заказ?', 'Delete order?'),
      message: context.tr(
        'Заказ «${_order?.title ?? ''}» и история его платежей будут удалены безвозвратно.',
        'Order "${_order?.title ?? ''}" and its payment history will be permanently deleted.',
      ),
    );
    if (confirm == true && mounted) {
      await op.delete(widget.orderId);
      dash.reload();
      router.go('/orders');
    }
  }

  void _showPaymentSheet(BuildContext context) {
    final colors = context.appColors;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final currency = context.read<SettingsProvider>().currency;
    final remainingCents = _order!.remainingCents;
    final formattedRemaining =
        FinancialCalculator.formatCents(remainingCents, currency: currency);

    showAppModal(
      context: context,
      child: AppModalSheet(
        title: context.tr('Записать платёж', 'Record payment'),
        subtitle: context.tr(
          'Остаток по заказу: $formattedRemaining',
          'Order balance: $formattedRemaining',
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
            Navigator.of(context, rootNavigator: true).pop();
            HapticFeedback.mediumImpact();
            const uuid = Uuid();
            await context.read<OrderProvider>().recordPayment(
                  orderId: _order!.id,
                  customerId: _order!.customerId,
                  amountCents: cents.clamp(0, remainingCents),
                  paymentId: uuid.v4(),
                  transactionId: uuid.v4(),
                  notes: notesCtrl.text.trim().isNotEmpty
                      ? notesCtrl.text.trim()
                      : null,
                );
            if (mounted) {
              context.read<DashboardProvider>().reload();
            }
            _load();
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
                    context.tr(
                      'Весь остаток ($formattedRemaining)',
                      'Full balance ($formattedRemaining)',
                    ),
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
                hint: context.tr(
                  'Наличные, перевод на карту и т.д.',
                  'Cash, card transfer, etc.',
                ),
              ),
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
          child: Text(
            context.tr('Заказ не найден', 'Order not found'),
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final order = _order!;
    final canRecordPayment =
        !order.isFullyPaid && order.status != OrderStatus.cancelled;

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: canRecordPayment
          ? Container(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                12,
                _kPagePadding,
                12,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: SafeArea(
                top: false,
                child: FormSubmitButton(
                  label: context.tr('Записать платёж', 'Record payment'),
                  icon: Icons.add_card_rounded,
                  accentColor: colors.primary,
                  isLoading: false,
                  onPressed: () => _showPaymentSheet(context),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Navigation Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kPagePadding,
                AppSpacing.sm,
                _kPagePadding,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  _IconNavButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/orders');
                      }
                    },
                  ),
                  const Spacer(),
                  _NavActionPill(
                    label: context.tr('Изменить', 'Edit'),
                    icon: Icons.edit_outlined,
                    onTap: _editOrder,
                  ),
                  const SizedBox(width: 8),
                  _NavActionPill(
                    label: context.tr('Удалить', 'Delete'),
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: () => _delete(context),
                  ),
                ],
              ),
            ),

            // ── 2. Scrollable Content ──────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: colors.primary,
                backgroundColor: colors.surface,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    _kPagePadding,
                    AppSpacing.sm,
                    _kPagePadding,
                    40,
                  ),
                  children: [
                    // ── Order Header & Financial Progress Card ─────────────
                    _OrderOverviewCard(
                      order: order,
                      currency: currency,
                      onTapCustomer: () {
                        HapticFeedback.selectionClick();
                        context.push('/profile/customers/${order.customerId}');
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Interactive Status Switcher Card ───────────────────
                    _StatusSwitcherCard(
                      current: order.status,
                      isChanging: _statusChanging,
                      onSelect: _changeStatus,
                    ),

                    const SizedBox(height: 12),

                    // ── Dates & Details Bento Card ─────────────────────────
                    _OrderDetailsCard(order: order),

                    const SizedBox(height: 20),

                    // ── Payment History Section ────────────────────────────
                    _PaymentHistorySection(
                      payments: _payments,
                      currency: currency,
                      isFullyPaid: order.isFullyPaid,
                      onAddPayment: canRecordPayment
                          ? () => _showPaymentSheet(context)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar Buttons ─────────────────────────────────────────────────────────

class _IconNavButton extends StatelessWidget {
  const _IconNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 20, color: colors.textPrimary),
      ),
    );
  }
}

class _NavActionPill extends StatelessWidget {
  const _NavActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = danger ? colors.expense : colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 1. Order Overview & Financial Progress Card ─────────────────────────────

class _OrderOverviewCard extends StatelessWidget {
  const _OrderOverviewCard({
    required this.order,
    required this.currency,
    required this.onTapCustomer,
  });

  final Order order;
  final String currency;
  final VoidCallback onTapCustomer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPaid = order.isFullyPaid;
    final isCancelled = order.status == OrderStatus.cancelled;
    final progress = order.paymentProgress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();

    final barColor = isCancelled
        ? colors.textMuted
        : (isPaid ? colors.income : colors.primary);
    final payBadgeColor = isPaid ? colors.income : colors.primary;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge + Solid Paid % Badge
          Row(
            children: [
              AppStatusBadge.order(order.status, context),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: payBadgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaid
                          ? Icons.verified_rounded
                          : Icons.pie_chart_outline_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPaid
                          ? context.tr('Оплачен полностью', 'Fully paid')
                          : context.tr(
                              'Оплачено $progressPercent%',
                              'Paid $progressPercent%',
                            ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Order Title
          Text(
            order.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // Interactive Customer Row
          GestureDetector(
            onTap: onTapCustomer,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      order.customerName.trim().isNotEmpty
                          ? order.customerName.trim()[0].toUpperCase()
                          : context.tr('К', 'C'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Клиент', 'Customer'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (_, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 7,
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3 Financial Columns: Стоимость | Получено | Остаток
          Row(
            children: [
              Expanded(
                child: _FinMetricBox(
                  label: context.tr('Стоимость', 'Total'),
                  amount: FinancialCalculator.formatCents(
                    order.totalPriceCents,
                    currency: currency,
                  ),
                  color: colors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: colors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: _FinMetricBox(
                  label: context.tr('Получено', 'Paid'),
                  amount: FinancialCalculator.formatCents(
                    order.receivedCents,
                    currency: currency,
                  ),
                  color: colors.income,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: colors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: _FinMetricBox(
                  label: context.tr('Остаток', 'Balance'),
                  amount: FinancialCalculator.formatCents(
                    order.remainingCents,
                    currency: currency,
                  ),
                  color: isPaid ? colors.income : colors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinMetricBox extends StatelessWidget {
  const _FinMetricBox({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 2. Interactive Status Switcher Card ─────────────────────────────────────

class _StatusSwitcherCard extends StatelessWidget {
  const _StatusSwitcherCard({
    required this.current,
    required this.isChanging,
    required this.onSelect,
  });

  final OrderStatus current;
  final bool isChanging;
  final Future<void> Function(OrderStatus) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final statuses = [
      (
        status: OrderStatus.newOrder,
        label: context.tr('Новый', 'New'),
        icon: Icons.fiber_new_rounded,
      ),
      (
        status: OrderStatus.inProgress,
        label: context.tr('В работе', 'In progress'),
        icon: Icons.timelapse_rounded,
      ),
      (
        status: OrderStatus.completed,
        label: context.tr('Завершён', 'Completed'),
        icon: Icons.check_circle_outline_rounded,
      ),
      (
        status: OrderStatus.cancelled,
        label: context.tr('Отменён', 'Cancelled'),
        icon: Icons.cancel_outlined,
      ),
    ];

    Color colorFor(OrderStatus s) => switch (s) {
          OrderStatus.newOrder => const Color(0xFF2563EB),
          OrderStatus.inProgress => const Color(0xFFD97706),
          OrderStatus.completed => colors.income,
          OrderStatus.cancelled => const Color(0xFF475569),
        };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 15,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('СТАТУС ЗАКАЗА', 'ORDER STATUS'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textSecondary,
                ),
              ),
              if (isChanging) ...[
                const Spacer(),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.1,
            children: statuses.map((item) {
              final selected = current == item.status;
              final accent = colorFor(item.status);
              return GestureDetector(
                onTap: () => onSelect(item.status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected ? accent : colors.surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected ? accent : colors.border,
                      width: 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: selected ? Colors.white : accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── 3. Dates, Description & Notes Card ──────────────────────────────────────

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasDescription =
        order.description != null && order.description!.trim().isNotEmpty;
    final hasNotes = order.notes != null && order.notes!.trim().isNotEmpty;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isActive = order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled;

    bool isOverdue = false;
    bool isDueToday = false;
    if (order.dueDate != null && isActive) {
      final dueDay = DateTime(
        order.dueDate!.year,
        order.dueDate!.month,
        order.dueDate!.day,
      );
      isOverdue = dueDay.isBefore(today);
      isDueToday = dueDay.isAtSameMomentAs(today);
    }

    final dueColor = isOverdue
        ? colors.expense
        : (isDueToday ? colors.warning : colors.textPrimary);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dates Row
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  icon: Icons.calendar_today_outlined,
                  label: context.tr('Дата создания', 'Created'),
                  value: DateHelper.formatDate(order.createdAt),
                  iconColor: colors.primary,
                  valueColor: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTile(
                  icon: isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.event_outlined,
                  label: isOverdue
                      ? context.tr('Просрочен', 'Overdue')
                      : context.tr('Дедлайн', 'Deadline'),
                  value: order.dueDate != null
                      ? DateHelper.formatDate(order.dueDate!)
                      : context.tr('Не указан', 'Not set'),
                  iconColor: order.dueDate != null ? dueColor : colors.textMuted,
                  valueColor:
                      order.dueDate != null ? dueColor : colors.textMuted,
                ),
              ),
            ],
          ),

          if (hasDescription) ...[
            const SizedBox(height: 14),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),
            Text(
              context.tr('ОПИСАНИЕ РАБОТЫ', 'WORK DESCRIPTION'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              order.description!.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.textPrimary,
              ),
            ),
          ],

          if (hasNotes) ...[
            const SizedBox(height: 14),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 13, color: colors.textMuted),
                const SizedBox(width: 5),
                Text(
                  context.tr('ЗАМЕТКИ', 'NOTES'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.notes!.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. Payment History Section ──────────────────────────────────────────────

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.payments,
    required this.currency,
    required this.isFullyPaid,
    this.onAddPayment,
  });

  final List<OrderPayment> payments;
  final String currency;
  final bool isFullyPaid;
  final VoidCallback? onAddPayment;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr('История платежей', 'Payment history'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${payments.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Платежей пока нет', 'No payments yet'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Все поступления по заказу будут отображаться здесь',
                          'All order payments will appear here',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < payments.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 62,
                      color: colors.divider,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.income,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.south_west_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateHelper.formatDate(payments[i].paidAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (payments[i].notes != null &&
                                  payments[i].notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  payments[i].notes!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '+${FinancialCalculator.formatCents(payments[i].amountCents, currency: currency)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.income,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
