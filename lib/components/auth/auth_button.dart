import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum AuthButtonVariant { primary, text, outline }

/// Ink CTA with a hard teal offset — more character than a soft rounded pill.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AuthButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback onPressed;
  final AuthButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    switch (variant) {
      case AuthButtonVariant.primary:
        return _buildPrimaryButton(colors);
      case AuthButtonVariant.outline:
        return _buildOutlineButton(colors);
      case AuthButtonVariant.text:
        return _buildTextButton(colors);
    }
  }

  Widget _buildPrimaryButton(AppSemanticColors colors) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 56,
      child: Stack(
        children: [
          Positioned(
            left: 4,
            top: 4,
            right: 0,
            bottom: 0,
            child: Container(color: colors.primary),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Material(
                color: AppColors.ink,
                child: InkWell(
                  onTap: isLoading ? null : onPressed,
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineButton(AppSemanticColors colors) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.ink, width: 1.5),
          shape: const RoundedRectangleBorder(),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildTextButton(AppSemanticColors colors) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colors.textSecondary),
                ),
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label.contains('?')
                          ? '${label.split('?').first}? '
                          : label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (label.contains('?'))
                      TextSpan(
                        text: label.split('?').last.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
