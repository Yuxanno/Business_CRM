import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _onSelectTab(int index) {
    HapticFeedback.selectionClick();
    final currentIdx = navigationShell.currentIndex;
    final isSame = index == currentIdx;
    navigationShell.goBranch(index, initialLocation: isSame);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: RepaintBoundary(
        child: navigationShell,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _BottomNavBarContent(
                currentIndex: currentIndex,
                onSelect: _onSelectTab,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBarContent extends StatelessWidget {
  const _BottomNavBarContent({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const int _tabCount = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final clampedIndex = currentIndex.clamp(0, _tabCount - 1);
    final alignX = -1.0 + (2.0 * clampedIndex / (_tabCount - 1));

    return Stack(
      children: [
        // Sliding pill indicator behind the active tab icon
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              alignment: Alignment(alignX, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / _tabCount,
                heightFactor: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 53,
                      height: 29,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      ' ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: context.tr('Главная', 'Home'),
              selected: clampedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
              label: context.tr('Деньги', 'Finance'),
              selected: clampedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: context.tr('Заказы', 'Orders'),
              selected: clampedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: context.tr('Ещё', 'More'),
              selected: clampedIndex == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ],
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
            SizedBox(
              width: 53,
              height: 29,
              child: Center(
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 21,
                  color: selected ? colors.primary : colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 3),
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
