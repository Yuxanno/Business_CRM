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
import '../../components/app_skeleton.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;
  String _searchQuery = '';

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
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Debt> _filtered(List<Debt> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list
        .where((d) =>
            d.personName.toLowerCase().contains(q) ||
            (d.description?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final provider = context.watch<DebtProvider>();
    final currency = context.watch<SettingsProvider>().currency;

    final receivables = _filtered(provider.receivables);
    final payables = _filtered(provider.payables);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _searchActive
                    ? _SearchField(
                        key: const ValueKey('search'),
                        controller: _searchCtrl,
                        hint: 'Поиск по имени или описанию…',
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                        onClose: () {
                          setState(() {
                            _searchActive = false;
                            _searchQuery = '';
                          });
                          _searchCtrl.clear();
                        },
                      )
                    : Row(
                        key: const ValueKey('title'),
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 22, color: colors.textPrimary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Долги',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          // Search button
                          GestureDetector(
                            onTap: () =>
                                setState(() => _searchActive = true),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.border),
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

            // ── Tabs ──────────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.sm),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Мне должны'),
                      if (provider.receivables.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: provider.receivables.length,
                          color: colors.income,
                        ),
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
                        _TabBadge(
                          count: provider.payables.length,
                          color: colors.expense,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DebtList(
                    debts: receivables,
                    isLoading: provider.isLoading,
                    currency: currency,
                    emptyTitle: _searchQuery.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Никто вам не должен',
                    emptySubtitle: _searchQuery.isNotEmpty
                        ? 'Попробуйте другой запрос'
                        : 'Добавьте запись о деньгах, которые вам должны',
                    direction: DebtDirection.receivable,
                  ),
                  _DebtList(
                    debts: payables,
                    isLoading: provider.isLoading,
                    currency: currency,
                    emptyTitle: _searchQuery.isNotEmpty
                        ? 'Ничего не найдено'
                        : 'Вы никому не должны',
                    emptySubtitle: _searchQuery.isNotEmpty
                        ? 'Попробуйте другой запрос'
                        : 'Добавьте запись о деньгах, которые вы должны',
                    direction: DebtDirection.payable,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab badge ────────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final String hint;
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
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(Icons.arrow_back_rounded,
                size: 22, color: colors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
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
                hintText: widget.hint,
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
          if (hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.close_rounded,
                    size: 18, color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Debt list tab ────────────────────────────────────────────────────────────

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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: const AppSkeletonList(),
      );
    }

    if (debts.isEmpty) {
      return AppEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Добавить',
        onAction: () => context.push('/profile/debts/new'),
      );
    }

    final activeDebts = debts.where((d) => !d.isFullyPaid).toList();
    final totalCents =
        activeDebts.fold<int>(0, (s, d) => s + d.remainingCents);

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => context.read<DebtProvider>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 100),
        itemCount: debts.length + (activeDebts.isNotEmpty ? 1 : 0),
        itemBuilder: (ctx, i) {
          // First item = summary banner
          if (activeDebts.isNotEmpty && i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SummaryBanner(
                totalCents: totalCents,
                count: activeDebts.length,
                currency: currency,
                direction: direction,
              ),
            );
          }
          final debt = debts[activeDebts.isNotEmpty ? i - 1 : i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DebtCard(
              debt: debt,
              currency: currency,
              onTap: () => ctx.go('/profile/debts/${debt.id}'),
              onEdit: () =>
                  ctx.push('/profile/debts/${debt.id}/edit'),
              onDelete: () => _confirmDelete(ctx, debt),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Debt debt) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить долг?',
      message: 'История платежей будет удалена.',
    );
    if (confirm == true && context.mounted) {
      await context.read<DebtProvider>().delete(debt.id);
    }
  }
}

// ─── Summary banner ───────────────────────────────────────────────────────────

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

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReceivable
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : [const Color(0xFF9F1239), const Color(0xFFBE123C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReceivable
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceivable
                      ? 'Итого к получению'
                      : 'Итого к выплате',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  FinancialCalculator.formatCents(totalCents,
                      currency: currency),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count акт.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Debt card ────────────────────────────────────────────────────────────────

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
    final isReceivable =
        debt.direction == DebtDirection.receivable;
    final status = debt.computedStatus;
    final accentColor = isReceivable ? colors.income : colors.expense;
    final progress =
        (debt.paidAmountCents / debt.originalAmountCents).clamp(0.0, 1.0);
    final isOverdue = status == DebtStatus.overdue;

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
            // ── Top row ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    debt.personName.isNotEmpty
                        ? debt.personName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (debt.description != null &&
                          debt.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          debt.description!,
                          style: TextStyle(
                              fontSize: 12, color: colors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge.debt(status, context),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Progress ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colors.surfaceSecondary,
                          valueColor: AlwaysStoppedAnimation(
                            debt.isFullyPaid
                                ? colors.income
                                : isOverdue
                                    ? colors.expense
                                    : accentColor,
                          ),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debt.isFullyPaid
                            ? 'Погашен полностью'
                            : 'Оплачено ${FinancialCalculator.formatCentsCompact(debt.paidAmountCents, currency: currency)} из ${FinancialCalculator.formatCentsCompact(debt.originalAmountCents, currency: currency)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: debt.isFullyPaid
                              ? colors.income
                              : colors.textMuted,
                          fontWeight: debt.isFullyPaid
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Remaining amount
                if (!debt.isFullyPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FinancialCalculator.formatCents(
                            debt.remainingCents,
                            currency: currency),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isOverdue
                              ? colors.expense
                              : accentColor,
                          letterSpacing: -0.3,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                      Text(
                        'осталось',
                        style: TextStyle(
                            fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ),
              ],
            ),

            // ── Due date ─────────────────────────────────────────────────
            if (debt.dueDate != null && !debt.isFullyPaid) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_today_outlined,
                    size: 12,
                    color:
                        isOverdue ? colors.expense : colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'Просрочен · ${DateHelper.formatDate(debt.dueDate!)}'
                        : 'до ${DateHelper.formatDate(debt.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isOverdue
                          ? colors.expense
                          : colors.textMuted,
                    ),
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
