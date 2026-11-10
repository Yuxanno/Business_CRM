import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _tabs = ['/home', '/finance', '/orders', '/profile'];

  int _locationToIndex(String location) {
    if (location.startsWith('/finance')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  /// Plus only on lists where this page can create a record.
  String? _createKind(String path) => switch (path) {
        '/finance' => 'finance',
        '/orders' => 'order',
        '/profile/customers' => 'customer',
        '/profile/debts' => 'debt',
        _ => null,
      };

  Future<void> _onCreate(BuildContext context, String kind) async {
    HapticFeedback.lightImpact();
    switch (kind) {
      case 'finance':
        // Сразу открываем форму транзакции (без промежуточного выбора)
        context.push('/finance/new');
      case 'order':
        context.push('/orders/new');
      case 'customer':
        context.push('/profile/customers/new');
      case 'debt':
        context.push('/profile/debts/new');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = _locationToIndex(path);
    final createKind = _createKind(path);

    return Scaffold(
      body: child,
      floatingActionButton: createKind == null
          ? null
          : FloatingActionButton(
              heroTag: 'shell-create',
              onPressed: () => _onCreate(context, createKind),
              backgroundColor: AppColors.ink,
              foregroundColor: colors.onPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  onTap: () => context.go(_tabs[0]),
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Деньги',
                  selected: currentIndex == 1,
                  onTap: () => context.go(_tabs[1]),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Заказы',
                  selected: currentIndex == 2,
                  onTap: () => context.go(_tabs[2]),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Ещё',
                  selected: currentIndex == 3,
                  onTap: () => context.go(_tabs[3]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.primary : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
