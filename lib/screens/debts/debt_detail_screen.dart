import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/debt.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_button.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_templates.dart';

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
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<DebtProvider>();
    final debt = await provider.getById(widget.debtId);
    final payments = await provider.getPaymentsForDebt(widget.debtId);
    setState(() {
      _debt = debt;
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

    if (_debt == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: Center(
          child: Text('Долг не найден',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }

    final debt = _debt!;
    final isReceivable = debt.direction == DebtDirection.receivable;
    final accentColor = isReceivable ? colors.income : colors.expense;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AppDetailHeader(
            title: debt.personName,
            subtitle: isReceivable
                ? 'Этот человек должен вам${debt.dueDate == null ? '' : '. Срок: ${DateHelper.formatDate(debt.dueDate!)}'}'
                : 'Вы должны этому человеку${debt.dueDate == null ? '' : '. Срок: ${DateHelper.formatDate(debt.dueDate!)}'}',
            status: AppStatusBadge.debt(debt.computedStatus, context),
            amountLabel: debt.isFullyPaid ? 'Погашено' : 'Осталось',
            amount: FinancialCalculator.formatCents(
              debt.isFullyPaid ? debt.originalAmountCents : debt.remainingCents,
              currency: currency,
            ),
            amountColor: debt.isFullyPaid ? colors.income : accentColor,
            fallbackRoute: '/profile/debts',
            actions: [
              AppTextAction(
                label: 'Изменить',
                onPressed: () => context.push('/profile/debts/${debt.id}/edit'),
              ),
              AppTextAction(
                label: 'Удалить',
                onPressed: () => _delete(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Header card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isReceivable
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.personName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            isReceivable ? 'Должен вам' : 'Вы должны',
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    AppStatusBadge.debt(debt.computedStatus, context),
                  ],
                ),
                if (debt.description != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    debt.description!,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (debt.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 13,
                        color: debt.computedStatus == DebtStatus.overdue
                            ? colors.expense
                            : colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Срок: ${DateHelper.formatDate(debt.dueDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: debt.computedStatus == DebtStatus.overdue
                              ? colors.expense
                              : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Financial card
          AppCard(
            child: Column(
              children: [
                _FinRow(
                  label: 'Сумма долга',
                  value: FinancialCalculator.formatCents(
                      debt.originalAmountCents, currency: currency),
                  color: colors.textPrimary,
                  bold: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _FinRow(
                  label: 'Выплачено',
                  value: FinancialCalculator.formatCents(
                      debt.paidAmountCents, currency: currency),
                  color: colors.income,
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: colors.divider),
                const SizedBox(height: AppSpacing.sm),
                _FinRow(
                  label: 'Остаток',
                  value: FinancialCalculator.formatCents(
                      debt.remainingCents, currency: currency),
                  color: debt.isFullyPaid ? colors.income : accentColor,
                  bold: true,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (debt.paidAmountCents /
                            debt.originalAmountCents)
                        .clamp(0.0, 1.0),
                    backgroundColor: colors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation(
                      debt.isFullyPaid ? colors.income : accentColor,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Record payment button
          if (!debt.isFullyPaid)
            AppButton(
              label: 'Записать платёж',
              onPressed: () => _showPaymentSheet(context),
              icon: Icons.add_rounded,
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Payment history
          if (_payments.isNotEmpty) ...[
            Text(
              'История платежей',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._payments.map((p) => Padding(
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
          const SizedBox(height: 80),
        ],
        ),
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
            Text(
              'Записать платёж',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Остаток: ${FinancialCalculator.formatCents(_debt!.remainingCents, currency: currency)}',
              style: TextStyle(
                  fontSize: 12, color: colors.textSecondary),
            ),
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
                await context.read<DebtProvider>().recordPayment(
                      debtId: _debt!.id,
                      amountCents: cents.clamp(0, _debt!.remainingCents),
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
      title: 'Удалить долг?',
      message: 'Это действие нельзя отменить.',
    );
    if (confirm == true && mounted) {
      final dp = context.read<DebtProvider>();
      final router = GoRouter.of(context);
      await dp.delete(widget.debtId);
      router.go('/profile/debts');
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
                fontWeight: bold ? FontWeight.w500 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            )),
      ],
    );
  }
}
