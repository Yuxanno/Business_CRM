import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Widget child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foregroundColor(colors),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: _foregroundColor(colors),
                ),
              ),
            ],
          );

    final button = _buildButton(context, colors, child);

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildButton(
      BuildContext context, AppSemanticColors colors, Widget child) {
    final effectiveOnPressed = (isLoading || onPressed == null)
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };

    switch (variant) {
      case AppButtonVariant.primary:
        return SizedBox(
          height: height,
          child: ElevatedButton(
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.border,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: colors.primary, width: 0),
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return colors.border;
                }
                return AppColors.ink;
              }),
            ),
            child: child,
          ),
        );

      case AppButtonVariant.secondary:
        return SizedBox(
          height: height,
          child: ElevatedButton(
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: child,
          ),
        );

      case AppButtonVariant.outline:
        return SizedBox(
          height: height,
          child: OutlinedButton(
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: child,
          ),
        );

      case AppButtonVariant.text:
        return TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            minimumSize: Size(0, height),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: child,
        );

      case AppButtonVariant.danger:
        return SizedBox(
          height: height,
          child: ElevatedButton(
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.expense,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: child,
          ),
        );
    }
  }

  Color _foregroundColor(AppSemanticColors colors) => switch (variant) {
        AppButtonVariant.primary => colors.onPrimary,
        AppButtonVariant.secondary => colors.primary,
        AppButtonVariant.outline => colors.primary,
        AppButtonVariant.text => colors.primary,
        AppButtonVariant.danger => Colors.white,
      };
}
