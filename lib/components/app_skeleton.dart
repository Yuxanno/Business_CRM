import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Lightweight pulse placeholder — no external shimmer package.
/// Inside lists, pass [animate: false] and wrap with a single [_PulseGroup]
/// so only one AnimationController runs instead of one per bar.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
    this.animate = true,
  });

  final double height;
  final double? width;
  final double radius;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (!animate) return bar;
    return _PulseGroup(child: bar);
  }
}

class _PulseGroup extends StatefulWidget {
  const _PulseGroup({required this.child});
  final Widget child;

  @override
  State<_PulseGroup> createState() => _PulseGroupState();
}

class _PulseGroupState extends State<_PulseGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.40, end: 0.86).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 8});

  /// Maximum number of items to show. The actual number shown
  /// is capped by available height so it never overflows.
  final int count;

  @override
  Widget build(BuildContext context) {
    const cardHeight = 48.0 + 14 + 16 + 12 + 8 + 12; // ≈ 110
    const cardSpacing = AppSpacing.md;
    final colors = context.appColors;

    return _PulseGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight;
          final fits = available.isFinite
              ? ((available + cardSpacing) / (cardHeight + cardSpacing))
                  .floor()
                  .clamp(1, count)
              : count;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(fits, (i) {
              final isLast = i == fits - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : cardSpacing),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(height: 14, width: 140, animate: false),
                      SizedBox(height: AppSpacing.md),
                      AppSkeleton(height: 12, animate: false),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeleton(height: 12, width: 180, animate: false),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
