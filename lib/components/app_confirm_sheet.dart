import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Bottom sheet for confirming destructive or important operations.
Future<bool?> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDanger = true,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF09191F).withValues(alpha: 0.52),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (_) => AppConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? context.tr('Удалить', 'Delete'),
      cancelLabel: cancelLabel ?? context.tr('Отмена', 'Cancel'),
      isDanger: isDanger,
    ),
  );
}

class AppConfirmSheet extends StatelessWidget {
  const AppConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.isDanger = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = isDanger ? colors.expense : colors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Icon badge
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Icon(
              isDanger
                  ? Icons.delete_forever_rounded
                  : Icons.help_outline_rounded,
              size: 28,
              color: accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: cancelLabel,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, false);
                  },
                  variant: AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context, true);
                  },
                  variant: isDanger
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
