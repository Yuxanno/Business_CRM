import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Lightweight pulse placeholder — no external shimmer package.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.85).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 8});

  /// Maximum number of items to show. The actual number shown
  /// is capped by available height so it never overflows.
  final int count;

  @override
  Widget build(BuildContext context) {
    // Each card: padding(24)*2 + line14 + gap16 + line12 + gap8 + line12 + bottom(16)
    const cardHeight = 48.0 + 14 + 16 + 12 + 8 + 12; // ≈ 110
    const cardSpacing = AppSpacing.md;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        // How many cards fit without overflow (at least 1)
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
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : cardSpacing),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: context.appColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(height: 14, width: 140),
                    SizedBox(height: AppSpacing.md),
                    AppSkeleton(height: 12),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(height: 12, width: 180),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
