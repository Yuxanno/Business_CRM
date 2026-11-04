import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _fabExpanded = false;

  static const _tabs = ['/home', '/finance', '/orders', '/profile'];

  int _locationToIndex(String location) {
    if (location.startsWith('/finance')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTabTap(int index) {
    setState(() => _fabExpanded = false);
    context.go(_tabs[index]);
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() => _fabExpanded = !_fabExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // Dim overlay when FAB expanded
          if (_fabExpanded)
            GestureDetector(
              onTap: () => setState(() => _fabExpanded = false),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          // FAB quick actions
          if (_fabExpanded)
            Positioned(
              bottom: 100 + MediaQuery.of(context).padding.bottom,
              right: AppSpacing.xl,
              child: _QuickActionsMenu(
                onAction: (action) {
                  setState(() => _fabExpanded = false);
                  _handleQuickAction(action);
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Главная',
                  selected: currentIndex == 0,
                  onTap: () => _onTabTap(0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Финансы',
                  selected: currentIndex == 1,
                  onTap: () => _onTabTap(1),
                ),
                // Central FAB placeholder
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _toggleFab,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _fabExpanded
                              ? colors.expenseBackground
                              : colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedRotation(
                          turns: _fabExpanded ? 0.125 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.add_rounded,
                            color: _fabExpanded
                                ? colors.expense
                                : colors.onPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Заказы',
                  selected: currentIndex == 2,
                  onTap: () => _onTabTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Профиль',
                  selected: currentIndex == 3,
                  onTap: () => _onTabTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'income':
        context.go('/finance/new');
        break;
      case 'expense':
        context.go('/finance/new');
        break;
      case 'order':
        context.go('/orders/new');
        break;
      case 'debt':
        context.go('/profile/debts/new');
        break;
      case 'customer':
        context.go('/profile/customers/new');
        break;
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? colors.primary : colors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? colors.primary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsMenu extends StatelessWidget {
  const _QuickActionsMenu({required this.onAction});
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final actions = [
      (icon: Icons.trending_up_rounded, label: 'Доход', key: 'income', color: colors.income),
      (icon: Icons.trending_down_rounded, label: 'Расход', key: 'expense', color: colors.expense),
      (icon: Icons.receipt_long_rounded, label: 'Заказ', key: 'order', color: colors.primary),
      (icon: Icons.account_balance_wallet_outlined, label: 'Долг', key: 'debt', color: colors.warning),
      (icon: Icons.person_add_rounded, label: 'Клиент', key: 'customer', color: AppColors.slate500),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: actions.map((a) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  a.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => onAction(a.key),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
