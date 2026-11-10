import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Editorial auth header — brand-first, no generic gradient icon tile.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow = 'Biznes CRM',
  });

  final String title;
  final String subtitle;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 28,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            height: 1.05,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 48,
          height: 4,
          color: colors.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}
