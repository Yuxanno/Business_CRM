import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/financial_calculator.dart';
import '../../components/app_card.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_confirm_sheet.dart';
import '../../components/app_skeleton.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().load();
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
    final provider = context.watch<CustomerProvider>();
    final currency = context.watch<SettingsProvider>().currency;

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
                        hint: 'Поиск по имени или телефону…',
                        onChanged: provider.setSearch,
                        onClose: () {
                          setState(() => _searchActive = false);
                          _searchCtrl.clear();
                          provider.setSearch('');
                        },
                      )
                    : Row(
                        key: const ValueKey('title'),
                        children: [
                          // Back
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 22, color: colors.textPrimary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Клиенты',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          // Count badge
                          if (provider.customers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${provider.customers.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          const SizedBox(width: AppSpacing.sm),
                          // Search toggle — always visible
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

            const SizedBox(height: AppSpacing.sm),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: provider.isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                      child: const AppSkeletonList(count: 6),
                    )
                  : provider.customers.isEmpty
                      ? AppEmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'Клиентов пока нет',
                          subtitle:
                              'Добавьте клиента — заказы и долги привяжутся к нему',
                          actionLabel: 'Добавить клиента',
                          onAction: () =>
                              context.push('/profile/customers/new'),
                        )
                      : RefreshIndicator(
                          color: colors.primary,
                          onRefresh: () =>
                              context.read<CustomerProvider>().load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.xs,
                                AppSpacing.xl,
                                100),
                            itemCount: provider.customers.length,
                            itemBuilder: (ctx, i) {
                              final c = provider.customers[i];
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _CustomerCard(
                                  customer: c,
                                  currency: currency,
                                  onTap: () => context
                                      .go('/profile/customers/${c.id}'),
                                  onEdit: () => context.push(
                                      '/profile/customers/${c.id}/edit'),
                                  onDelete: () =>
                                      _confirmDelete(context, c),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Customer customer) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Удалить клиента?',
      message:
          'История заказов будет сохранена, но привязка к клиенту пропадёт.',
    );
    if (confirm == true && mounted) {
      await context.read<CustomerProvider>().delete(customer.id);
    }
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

// ─── Customer card ────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasDebt = customer.outstandingBalanceCents > 0;
    final initials = _initials(customer.name);

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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        onTap: onTap,
        child: Row(
          children: [
            // ── Avatar ─────────────────────────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasDebt
                    ? colors.warningBackground
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: hasDebt
                      ? AppColors.warningDark
                      : AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Info ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (customer.phone != null) ...[
                        Icon(Icons.phone_outlined,
                            size: 11, color: colors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          customer.phone!,
                          style: TextStyle(
                              fontSize: 12, color: colors.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (customer.totalOrdersCount > 0)
                        Text(
                          '${customer.totalOrdersCount} зак.',
                          style: TextStyle(
                              fontSize: 12, color: colors.textMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Debt / Chevron ─────────────────────────────────────────
            if (hasDebt) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FinancialCalculator.formatCentsCompact(
                        customer.outstandingBalanceCents,
                        currency: currency),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.warning,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'долг',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
