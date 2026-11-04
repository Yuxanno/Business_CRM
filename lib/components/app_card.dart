import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard surface card with consistent border, radius, and padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.margin,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? radius;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final r = radius ?? AppRadius.card;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(r),
                  child: Padding(
                    padding: padding ??
                        const EdgeInsets.all(AppSpacing.lg),
                    child: child,
                  ),
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
      ),
    );
  }
}

/// Larger summary card (20px radius) for financial overviews.
class AppSummaryCard extends StatelessWidget {
  const AppSummaryCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final LinearGradient? gradient;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? colors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: gradient == null
            ? Border.all(color: colors.border, width: 1)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: padding ??
                        const EdgeInsets.all(AppSpacing.xl),
                    child: child,
                  ),
                ),
              )
            : Padding(
                padding:
                    padding ?? const EdgeInsets.all(AppSpacing.xl),
                child: child,
              ),
      ),
    );
  }
}
