import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/debt.dart';
import '../../providers/customer_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_avatar.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';
import '../../l10n/app_tr.dart';

const double _kPagePadding = 20.0;

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
    final debtProvider = context.read<DebtProvider>();

    final results = await Future.wait([
      customerProvider.getById(widget.customerId),
      orderProvider.getByCustomer(widget.customerId),
      if (debtProvider.all.isEmpty) debtProvider.load(),
    ]);

    if (mounted) {
      setState(() {
        _customer = results[0] as Customer?;
        _orders = results[1] as List<Order>;
        _loading = false;
      });
    }
  }

  Future<void> _editCustomer() async {
    if (_customer == null) return;
    HapticFeedback.selectionClick();
    await context.push('/profile/customers/${_customer!.id}/edit');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _createOrder() async {
    HapticFeedback.mediumImpact();
    await context.push('/orders/new');
    if (mounted) {
      await _load();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cp = context.read<CustomerProvider>();
    final router = GoRouter.of(context);
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить клиента?', 'Delete customer?'),
      message: context.tr(
          'Профиль «${_customer?.name ?? ''}» будет удалён. История его заказов сохранится.',
          'Profile "${_customer?.name ?? ''}" will be deleted. Their order history will be preserved.'),
    );
    if (confirm == true && mounted) {
      await cp.delete(widget.customerId);
      router.go('/profile/customers');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final colors = context.appColors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.tr('$label скопирован: $text', '$label copied: $text'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = context.watch<SettingsProvider>().currency;
    final debtProvider = context.watch<DebtProvider>();

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (_customer == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(backgroundColor: colors.background, elevation: 0),
        body: Center(
          child: Text(
            context.tr('Клиент не найден', 'Customer not found'),
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final customer = _customer!;
    final customerDebts =
        debtProvider.debtsForCustomer(customer.id, customer.name);
    final extraDebtCents =
        debtProvider.remainingDebtForCustomer(customer.id, customer.name);

    return Scaffold(
      backgroundColor: colors.background,
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
                        context.go('/profile/customers');
                      }
                    },
                  ),
                  const Spacer(),
                  _NavActionPill(
                    label: context.tr('Изменить', 'Edit'),
                    icon: Icons.edit_outlined,
                    onTap: _editCustomer,
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
                onRefresh: () async {
                  await context.read<DebtProvider>().load();
                  await _load();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    _kPagePadding,
                    AppSpacing.sm,
                    _kPagePadding,
                    48,
                  ),
                  children: [
                    // ── Customer Profile & Financial Overview Card ─────────
                    _CustomerProfileCard(
                      customer: customer,
                      extraDebtCents: extraDebtCents,
                      currency: currency,
                      onCopyPhone: customer.phone != null &&
                              customer.phone!.trim().isNotEmpty
                          ? () => _copyToClipboard(
                                customer.phone!.trim(),
                                context.tr('Телефон', 'Phone'),
                              )
                          : null,
                      onCopyEmail: customer.email != null &&
                              customer.email!.trim().isNotEmpty
                          ? () => _copyToClipboard(
                                customer.email!.trim(),
                                'Email',
                              )
                          : null,
                    ),

                    // ── Customer Debts Section (if any) ────────────────────
                    if (customerDebts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _CustomerDebtsSection(
                        debts: customerDebts,
                        currency: currency,
                        onTapDebt: (debt) {
                          HapticFeedback.selectionClick();
                          context.push('/profile/debts/${debt.id}').then((_) {
                            if (mounted) _load();
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Customer Orders Section ────────────────────────────
                    _CustomerOrdersSection(
                      orders: _orders,
                      currency: currency,
                      onNewOrder: _createOrder,
                      onTapOrder: (order) {
                        HapticFeedback.selectionClick();
                        context.push('/orders/${order.id}').then((_) {
                          if (mounted) _load();
                        });
                      },
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

// ─── 1. Customer Overview & Financial Card ───────────────────────────────────

class _CustomerProfileCard extends StatelessWidget {
  const _CustomerProfileCard({
    required this.customer,
    required this.extraDebtCents,
    required this.currency,
    this.onCopyPhone,
    this.onCopyEmail,
  });

  final Customer customer;
  final int extraDebtCents;
  final String currency;
  final VoidCallback? onCopyPhone;
  final VoidCallback? onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalDebtCents = customer.outstandingBalanceCents + extraDebtCents;
    final hasDebt = totalDebtCents > 0;
    final hasPhone =
        customer.phone != null && customer.phone!.trim().isNotEmpty;
    final hasEmail =
        customer.email != null && customer.email!.trim().isNotEmpty;
    final hasNotes =
        customer.notes != null && customer.notes!.trim().isNotEmpty;

    final totalObligations =
        customer.totalOrdersAmountCents + extraDebtCents;
    final progress = totalObligations > 0
        ? (customer.totalReceivedCents / totalObligations).clamp(0.0, 1.0)
        : 1.0;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Avatar + Name + Created Date | Status Badge ───────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: customer.name, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(
                          'В базе с ${DateHelper.formatDate(customer.createdAt)}',
                          'Added ${DateHelper.formatDate(customer.createdAt)}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hasDebt ? const Color(0xFFD97706) : colors.income,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasDebt
                      ? context.tr('Есть долг', 'Has debt')
                      : context.tr('Без долгов', 'No debt'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          // ── Contacts Row (Tap to Copy) ───────────────────────────────────
          const SizedBox(height: 14),
          if (hasPhone || hasEmail)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasPhone)
                  _ContactChip(
                    icon: Icons.phone_outlined,
                    label: customer.phone!.trim(),
                    onTap: onCopyPhone,
                  ),
                if (hasEmail)
                  _ContactChip(
                    icon: Icons.alternate_email_rounded,
                    label: customer.email!.trim(),
                    onTap: onCopyEmail,
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(
                        'Контактные данные не указаны', 'No contact details'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

          // ── Notes (if present) ───────────────────────────────────────────
          if (hasNotes) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 15, color: colors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.notes!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Progress Bar ─────────────────────────────────────────────────
          if (totalObligations > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (_, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 6,
                  backgroundColor: colors.surfaceSecondary,
                  valueColor: AlwaysStoppedAnimation(
                    hasDebt ? const Color(0xFFD97706) : colors.income,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 14),
          ],

          // ── 3 Financial Columns: Сумма заказов | Оплачено | Общий долг ───
          Row(
            children: [
              Expanded(
                child: _FinMetricBox(
                  label: context.tr('Сумма заказов', 'Total orders'),
                  amount: FinancialCalculator.formatCents(
                    customer.totalOrdersAmountCents,
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
                  label: context.tr('Оплачено', 'Paid'),
                  amount: FinancialCalculator.formatCents(
                    customer.totalReceivedCents,
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
                  label: context.tr('Остаток долга', 'Debt balance'),
                  amount: FinancialCalculator.formatCents(
                    totalDebtCents,
                    currency: currency,
                  ),
                  color: hasDebt ? const Color(0xFFD97706) : colors.income,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.copy_rounded,
              size: 12,
              color: colors.textMuted,
            ),
          ],
        ),
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

// ─── 2. Customer Debts Section ───────────────────────────────────────────────

class _CustomerDebtsSection extends StatelessWidget {
  const _CustomerDebtsSection({
    required this.debts,
    required this.currency,
    required this.onTapDebt,
  });

  final List<Debt> debts;
  final String currency;
  final ValueChanged<Debt> onTapDebt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr('Долги клиента', 'Customer debts'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${debts.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...debts.map(
          (debt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomerDebtCard(
              debt: debt,
              currency: currency,
              onTap: () => onTapDebt(debt),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerDebtCard extends StatelessWidget {
  const _CustomerDebtCard({
    required this.debt,
    required this.currency,
    required this.onTap,
  });

  final Debt debt;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPaid = debt.isFullyPaid;
    final status = debt.computedStatus;
    final isReceivable = debt.direction == DebtDirection.receivable;
    final progress = debt.originalAmountCents > 0
        ? (debt.paidAmountCents / debt.originalAmountCents).clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.description != null &&
                              debt.description!.trim().isNotEmpty
                          ? debt.description!.trim()
                          : (isReceivable
                              ? context.tr('Должен вам', 'Owes you')
                              : context.tr('Вы должны', 'You owe')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          'от ${DateHelper.formatDate(debt.createdAt)}${debt.dueDate != null ? ' • до ${DateHelper.formatShortDate(debt.dueDate!)}' : ''}',
                          '${DateHelper.formatDate(debt.createdAt)}${debt.dueDate != null ? ' • due ${DateHelper.formatShortDate(debt.dueDate!)}' : ''}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FinancialCalculator.formatCents(
                      isPaid ? debt.originalAmountCents : debt.remainingCents,
                      currency: currency,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isPaid
                          ? colors.income
                          : (isReceivable
                              ? const Color(0xFFD97706)
                              : colors.expense),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(
                isPaid ? colors.income : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                isPaid
                    ? context.tr('Погашен полностью', 'Fully paid')
                    : context.tr(
                        'Выплачено: ${FinancialCalculator.formatCents(debt.paidAmountCents, currency: currency)}',
                        'Paid: ${FinancialCalculator.formatCents(debt.paidAmountCents, currency: currency)}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPaid ? colors.income : colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!isPaid)
                Text(
                  context.tr(
                      'Сумма: ${FinancialCalculator.formatCents(debt.originalAmountCents, currency: currency)}',
                      'Total: ${FinancialCalculator.formatCents(debt.originalAmountCents, currency: currency)}'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 3. Customer Orders Section ──────────────────────────────────────────────

class _CustomerOrdersSection extends StatelessWidget {
  const _CustomerOrdersSection({
    required this.orders,
    required this.currency,
    required this.onNewOrder,
    required this.onTapOrder,
  });

  final List<Order> orders;
  final String currency;
  final VoidCallback onNewOrder;
  final ValueChanged<Order> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr('Заказы клиента', 'Customer orders'),
              style: TextStyle(
                fontSize: 17,
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
                '${orders.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onNewOrder,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('Новый заказ', 'New order'),
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
        const SizedBox(height: 12),
        if (orders.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
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
                        context.tr('Заказов пока нет', 'No orders yet'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                            'Создайте первый заказ для этого клиента',
                            'Create the first order for this customer'),
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
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CustomerOrderCard(
                order: order,
                currency: currency,
                onTap: () => onTapOrder(order),
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomerOrderCard extends StatelessWidget {
  const _CustomerOrderCard({
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
    final isPaid = order.isFullyPaid;
    final progress = order.paymentProgress.clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          'от ${DateHelper.formatDate(order.createdAt)}${order.dueDate != null ? ' • до ${DateHelper.formatShortDate(order.dueDate!)}' : ''}',
                          '${DateHelper.formatDate(order.createdAt)}${order.dueDate != null ? ' • due ${DateHelper.formatShortDate(order.dueDate!)}' : ''}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FinancialCalculator.formatCents(
                      order.totalPriceCents,
                      currency: currency,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppStatusBadge.order(order.status, context),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(
                isPaid ? colors.income : colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                isPaid
                    ? context.tr('Оплачен полностью', 'Fully paid')
                    : context.tr(
                        'Получено: ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}',
                        'Received: ${FinancialCalculator.formatCents(order.receivedCents, currency: currency)}'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPaid ? colors.income : colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!isPaid && order.status != OrderStatus.cancelled)
                Text(
                  context.tr(
                      'Остаток: ${FinancialCalculator.formatCents(order.remainingCents, currency: currency)}',
                      'Remaining: ${FinancialCalculator.formatCents(order.remainingCents, currency: currency)}'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
