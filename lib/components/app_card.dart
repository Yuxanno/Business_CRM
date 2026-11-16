import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard surface card with consistent border, radius, and padding.
/// Uses a crisp 1px border instead of blurred shadows by default so long
/// scrolling lists stay smooth on low-end GPUs.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.margin,
    this.color,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? radius;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final r = radius ?? AppRadius.card;
    final pad = padding ?? const EdgeInsets.all(AppSpacing.lg);
    final bg = color ?? colors.surface;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(r),
                child: Padding(padding: pad, child: child),
              ),
            )
          : Padding(padding: pad, child: child),
    );

    if (onTap == null) return card;
    return _TactileCardScale(child: card);
  }
}

class _TactileCardScale extends StatefulWidget {
  const _TactileCardScale({required this.child});
  final Widget child;

  @override
  State<_TactileCardScale> createState() => _TactileCardScaleState();
}

class _TactileCardScaleState extends State<_TactileCardScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
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
