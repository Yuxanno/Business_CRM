import 'package:flutter/material.dart';
import '../../l10n/app_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Social login buttons (placeholder for future implementation)
class SocialLogin extends StatelessWidget {
  const SocialLogin({
    super.key,
    required this.onGooglePressed,
    this.isLoading = false,
  });

  final VoidCallback onGooglePressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  context.tr('Или войдите через', 'Or continue with'),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onGooglePressed,
            icon: const Icon(Icons.g_mobiledata, size: 20),
            label: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.textSecondary),
                    ),
                  )
                : const Text('Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textSecondary,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
