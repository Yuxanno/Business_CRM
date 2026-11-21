import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/debt.dart';
import '../../providers/debt_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_modal_sheet.dart';
import '../../components/form_widgets.dart';
import '../../l10n/app_tr.dart';

const double _kPagePadding = 20.0;

class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});
  final String debtId;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  Debt? _debt;
  List<DebtPayment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final cached = context
        .read<DebtProvider>()
        .all
        .where((d) => d.id == widget.debtId)
        .firstOrNull;
    if (cached != null) {
      _debt = cached;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<DebtProvider>();
    final results = await Future.wait([
      provider.getById(widget.debtId),
      provider.getPaymentsForDebt(widget.debtId),
    ]);
    if (mounted) {
      setState(() {
        _debt = (results[0] as Debt?) ?? _debt;
        _payments = results[1] as List<DebtPayment>;
        _loading = false;
      });
    }
  }

  Future<void> _editDebt() async {
    if (_debt == null) return;
    HapticFeedback.selectionClick();
    await context.push('/profile/debts/${_debt!.id}/edit');
    if (mounted) {
      await _load();
      if (mounted) {
        context.read<DashboardProvider>().reload();
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final dp = context.read<DebtProvider>();
    final dash = context.read<DashboardProvider>();
    final router = GoRouter.of(context);
    final confirm = await showConfirmSheet(
      context: context,
      title: context.tr('Удалить долг?', 'Delete debt?'),
      message: context.tr(
          'Запись «${_debt?.personName ?? ''}» и история выплат по ней будут удалены безвозвратно.',
          'Record "${_debt?.personName ?? ''}" and its payment history will be permanently deleted.'),
    );
    if (confirm == true && mounted) {
      await dp.delete(widget.debtId);
      dash.reload();
      router.go('/profile/debts');
    }
  }

  void _showPaymentSheet(BuildContext context) {
    final colors = context.appColors;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final currency = context.read<SettingsProvider>().currency;
    final isReceivable = _debt!.direction == DebtDirection.receivable;
    final accent = isReceivable ? colors.income : colors.expense;
    final remainingCents = _debt!.remainingCents;
    final formattedRemaining =
        FinancialCalculator.formatCents(remainingCents, currency: currency);

    showAppModal(
      context: context,
      child: AppModalSheet(
        title: isReceivable
            ? context.tr('Принять возврат долга', 'Receive debt payment')
            : context.tr('Погашение долга', 'Debt repayment'),
        subtitle: context.tr('${_debt!.personName} • Остаток: $formattedRemaining',
            '${_debt!.personName} • Remaining: $formattedRemaining'),
        headerIcon: Icons.payments_outlined,
        headerColor: accent,
        bottomBar: FormSubmitButton(
          label: isReceivable
              ? context.tr('Зачислить возврат', 'Record receipt')
              : context.tr('Записать выплату', 'Record payment'),
          accentColor: accent,
          isLoading: false,
          icon: Icons.check_rounded,
          onPressed: () async {
            final cents =
                FinancialCalculator.parseAmountToCents(amountCtrl.text);
            if (cents == null || cents <= 0) return;
            Navigator.of(context, rootNavigator: true).pop();
            HapticFeedback.mediumImpact();
            const uuid = Uuid();
            await context.read<DebtProvider>().recordPayment(
                  debtId: _debt!.id,
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
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Весь остаток ($formattedRemaining)',
                        'Full balance ($formattedRemaining)'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              child: FormAmountField(
                controller: amountCtrl,
                accentColor: accent,
                prefix: isReceivable ? '+' : '−',
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
                hint: context.tr('Способ возврата или комментарий...',
                    'Payment method or comment...'),
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

    if (_debt == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(backgroundColor: colors.background, elevation: 0),
        body: Center(
          child: Text(
            context.tr('Долг не найден', 'Debt not found'),
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final debt = _debt!;
    final isReceivable = debt.direction == DebtDirection.receivable;
    final accentColor = isReceivable ? colors.income : colors.expense;

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: !debt.isFullyPaid
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
                  label: isReceivable
                      ? context.tr('Принять возврат', 'Collect payment')
                      : context.tr('Записать выплату', 'Record payment'),
                  icon: Icons.payments_outlined,
                  accentColor: accentColor,
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
                        context.go('/profile/debts');
                      }
                    },
                  ),
                  const Spacer(),
                  _NavActionPill(
                    label: context.tr('Изменить', 'Edit'),
                    icon: Icons.edit_outlined,
                    onTap: _editDebt,
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
                    // ── Debt Overview & Financial Progress Card ────────────
                    _DebtOverviewCard(
                      debt: debt,
                      currency: currency,
                    ),

                    const SizedBox(height: 12),

                    // ── Dates, Description & Notes Card ───────────────────
                    _DebtDetailsCard(debt: debt),

                    const SizedBox(height: 20),

                    // ── Payment History Section ───────────────────────────
                    _DebtPaymentHistorySection(
                      payments: _payments,
                      currency: currency,
                      isReceivable: isReceivable,
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
    final fg = danger ? colors.expense : colors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: danger ? const Color(0xFFFECDD3) : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 1. Debt Overview & Financial Progress Card ──────────────────────────────

class _DebtOverviewCard extends StatelessWidget {
  const _DebtOverviewCard({
    required this.debt,
    required this.currency,
  });

  final Debt debt;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isReceivable = debt.direction == DebtDirection.receivable;
    final isPaid = debt.isFullyPaid;
    final status = debt.computedStatus;
    final isOverdue = status == DebtStatus.overdue;

    final accentColor = isReceivable ? colors.income : colors.expense;
    final progress = debt.originalAmountCents > 0
        ? (debt.paidAmountCents / debt.originalAmountCents).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).round();

    final barColor = isPaid
        ? colors.income
        : (isOverdue ? colors.expense : accentColor);

    final initial = debt.personName.trim().isNotEmpty
        ? debt.personName.trim()[0].toUpperCase()
        : '?';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row: Direction Badge + Computed Status Badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReceivable
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isReceivable
                          ? context.tr('Мне должны', 'Owed to me')
                          : context.tr('Я должен', 'I owe'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppStatusBadge.debt(status, context),
            ],
          ),

          const SizedBox(height: 16),

          // Person Row with Solid Avatar
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
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
                      isReceivable
                          ? context.tr('Должник', 'Debtor')
                          : context.tr('Кредитор', 'Creditor'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      debt.personName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isPaid ? colors.income : colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
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

          // 3 Financial Columns: Сумма долга | Выплачено | Остаток
          Row(
            children: [
              Expanded(
                child: _FinMetricBox(
                  label: context.tr('Сумма долга', 'Debt total'),
                  amount: FinancialCalculator.formatCents(
                    debt.originalAmountCents,
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
                  label: isReceivable
                      ? context.tr('Возвращено', 'Returned')
                      : context.tr('Выплачено', 'Paid'),
                  amount: FinancialCalculator.formatCents(
                    debt.paidAmountCents,
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
                  label: context.tr('Остаток', 'Remaining'),
                  amount: FinancialCalculator.formatCents(
                    debt.remainingCents,
                    currency: currency,
                  ),
                  color: isPaid ? colors.income : accentColor,
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

// ─── 2. Dates, Description & Notes Card ──────────────────────────────────────

class _DebtDetailsCard extends StatelessWidget {
  const _DebtDetailsCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasDescription =
        debt.description != null && debt.description!.trim().isNotEmpty;
    final hasNotes = debt.notes != null && debt.notes!.trim().isNotEmpty;
    final isOverdue = debt.computedStatus == DebtStatus.overdue;

    final dueIconColor = debt.dueDate == null
        ? colors.textMuted
        : (isOverdue ? colors.expense : const Color(0xFF475569));
    final dueValueColor = debt.dueDate == null
        ? colors.textMuted
        : (isOverdue ? colors.expense : colors.textPrimary);

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
                  label: context.tr('Дата записи', 'Recorded on'),
                  value: DateHelper.formatDate(debt.createdAt),
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
                      ? context.tr('Просрочен с', 'Overdue since')
                      : context.tr('Срок возврата', 'Due date'),
                  value: debt.dueDate != null
                      ? DateHelper.formatDate(debt.dueDate!)
                      : context.tr('Без срока', 'No due date'),
                  iconColor: dueIconColor,
                  valueColor: dueValueColor,
                ),
              ),
            ],
          ),

          if (hasDescription) ...[
            const SizedBox(height: 14),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),
            Text(
              context.tr('ОСНОВАНИЕ / ЗА ЧТО', 'REASON'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              debt.description!.trim(),
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
              debt.notes!.trim(),
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

// ─── 3. Payment History Section ──────────────────────────────────────────────

class _DebtPaymentHistorySection extends StatelessWidget {
  const _DebtPaymentHistorySection({
    required this.payments,
    required this.currency,
    required this.isReceivable,
  });

  final List<DebtPayment> payments;
  final String currency;
  final bool isReceivable;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = isReceivable ? colors.income : colors.expense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr('История погашений', 'Payment history'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                        context.tr('Выплат пока нет', 'No payments yet'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                            'Все частичные и полные выплаты появятся здесь',
                            'All partial and full payments will appear here'),
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
                            color: accent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            isReceivable
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
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
                          '${isReceivable ? '+' : '−'}${FinancialCalculator.formatCents(payments[i].amountCents, currency: currency)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: accent,
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
