import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Opens a modern modal bottom sheet with a single tuned slide-up animation.
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
    barrierColor: const Color(0xFF09191F).withValues(alpha: 0.52),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (_) => child,
  );
}

/// Modern shell for modal sheets.
/// Supports a subtle tinted header, scrollable body, and an optional pinned [bottomBar]
/// so primary actions stay visible above the keyboard without being cut off.
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.headerColor,
    this.headerIcon,
    this.trailing,
    this.bottomBar,
    this.maxHeightFactor = 0.92,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Color? headerColor;
  final IconData? headerIcon;
  final Widget? trailing;
  final Widget? bottomBar;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final maxSheetHeight = availableHeight * maxHeightFactor;
    final accent = headerColor ?? colors.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with subtle top accent wash
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.08),
                        colors.surface,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: colors.divider,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _DragHandle(),
                      _SheetHeader(
                        title: title,
                        subtitle: subtitle,
                        color: accent,
                        icon: headerIcon,
                        trailing: trailing,
                      ),
                    ],
                  ),
                ),

                // Flexible scrollable content
                Flexible(
                  child: body,
                ),

                // Optional pinned bottom bar
                if (bottomBar != null)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      16 + (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        top: BorderSide(
                          color: colors.divider,
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: bottomBar!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Drag handle ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4.5,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ─── Sheet header ─────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.color,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
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
    this.trailingLabel,
  });

  final String label;
  final Widget child;
  final bool required;
  final Widget? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                  children: required
                      ? [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: colors.expense,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ]
                      : [],
                ),
              ),
            ),
            ?trailingLabel,
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
