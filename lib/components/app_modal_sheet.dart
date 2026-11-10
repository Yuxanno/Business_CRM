import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Opens a full-height draggable modal bottom sheet with slide-up animation.
Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => child,
  );
}

/// Animated shell for every modal form sheet.
/// Handles: drag-handle, header with icon + close button, scrollable body.
class AppModalSheet extends StatefulWidget {
  const AppModalSheet({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.headerColor,
    this.headerIcon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Color? headerColor;
  final IconData? headerIcon;
  final Widget? trailing;

  @override
  State<AppModalSheet> createState() => _AppModalSheetState();
}

class _AppModalSheetState extends State<AppModalSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final sheetHeight = (media.size.height - media.viewInsets.bottom) * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: child,
            ),
          ),
          child: SizedBox(
            height: sheetHeight,
            child: Material(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _DragHandle(),
                  _SheetHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    color: widget.headerColor,
                    icon: widget.headerIcon,
                    trailing: widget.trailing,
                  ),
                  Divider(height: 1, color: colors.divider),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Drag handle ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Sheet header ─────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    this.subtitle,
    this.color,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color? color;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = color ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          trailing ??
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: colors.textMuted),
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Field wrapper ────────────────────────────────────────────────────────────

/// Labelled field wrapper used inside modal forms.
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
            children: required
                ? [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(color: colors.expense))
                  ]
                : [],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
