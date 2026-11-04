import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/debt.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../services/date_helper.dart';
import '../../components/app_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<DebtProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Долги'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/profile/debts/new'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Мне должны'),
                  if (provider.receivables.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TabBadge(count: provider.receivables.length,
                        color: colors.income),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Я должен'),
                  if (provider.payables.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TabBadge(count: provider.payables.length,
                        color: colors.expense),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DebtList(
            debts: provider.receivables,
            isLoading: provider.isLoading,
            currency: currency,
            emptyTitle: 'Никто вам не должен',
            emptySubtitle: 'Добавьте запись о деньгах, которые вам должны',
            direction: DebtDirection.receivable,
          ),
          _DebtList(
            debts: provider.payables,
            isLoading: provider.isLoading,
            currency: currency,
            emptyTitle: 'Вы никому не должны',
            emptySubtitle: 'Добавьте запись о деньгах, которые вы должны',
            direction: DebtDirection.payable,
          ),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({
    required this.debts,
    required this.isLoading,
    required this.currency,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.direction,
  });

  final List<Debt> debts;
  final bool isLoading;
  final String currency;
  final String emptyTitle;
  final String emptySubtitle;
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (debts.isEmpty) {
      return AppEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Добавить',
        onAction: () => context.go('/profile/debts/new'),
      );
    }

    // Summary header
    final activeDebts = debts.where((d) => !d.isFullyPaid).toList();
    final totalCents = activeDebts.fold<int>(
        0, (sum, d) => sum + d.remainingCents);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => context.read<DebtProvider>().load(),
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 80),
        children: [
          if (activeDebts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _SummaryBanner(
              totalCents: totalCents,
              count: activeDebts.length,
              currency: currency,
              direction: direction,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...debts.map((debt) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DebtCard(
                  debt: debt,
                  currency: currency,
                  onTap: () =>
                      context.go('/profile/debts/${debt.id}'),
                  onEdit: () =>
                      context.go('/profile/debts/${debt.id}/edit'),
                  onDelete: () => _confirmDelete(context, debt),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Debt debt) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить долг?',
      message: 'История платежей будет удалена.',
    );
    if (confirm == true) {
      await context.read<DebtProvider>().delete(debt.id);
    }
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.totalCents,
    required this.count,
    required this.currency,
    required this.direction,
  });

  final int totalCents;
  final int count;
  final String currency;
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isReceivable = direction == DebtDirection.receivable;
    final color = isReceivable ? colors.income : colors.expense;
    final bg = isReceivable ? colors.incomeBackground : colors.expenseBackground;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(
            isReceivable
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceivable ? 'Итого к получению' : 'Итого к выплате',
                  style: TextStyle(fontSize: 12, color: color),
                ),
                Text(
                  FinancialCalculator.formatCents(totalCents,
                      currency: currency),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count активных',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Debt debt;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                    debt.personName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppStatusBadge.debt(debt.computedStatus, context),
              ],
            ),
            if (debt.description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                debt.description!,
                style: TextStyle(
                    fontSize: 12, color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (debt.paidAmountCents / debt.originalAmountCents)
                    .clamp(0.0, 1.0),
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation(
                  debt.isFullyPaid ? colors.income : colors.warning,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    debt.isFullyPaid
                        ? 'Погашен'
                        : 'Остаток: ${FinancialCalculator.formatCents(debt.remainingCents, currency: currency)}',
                    style: TextStyle(
                        fontSize: 11, color: colors.textMuted),
                  ),
                ),
                Text(
                  FinancialCalculator.formatCents(
                      debt.originalAmountCents, currency: currency),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            if (debt.dueDate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 11,
                      color: debt.computedStatus == DebtStatus.overdue
                          ? colors.expense
                          : colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'До ${DateHelper.formatDate(debt.dueDate!)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: debt.computedStatus == DebtStatus.overdue
                            ? colors.expense
                            : colors.textMuted),
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
