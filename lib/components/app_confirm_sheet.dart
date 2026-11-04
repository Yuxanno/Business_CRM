import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Bottom sheet for confirming destructive operations.
Future<bool?> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDanger = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => AppConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? 'Удалить',
      cancelLabel: cancelLabel ?? 'Отмена',
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

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
            variant:
                isDanger ? AppButtonVariant.danger : AppButtonVariant.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: cancelLabel,
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.text,
          ),
        ],
      ),
    );
  }
}
