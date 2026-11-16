import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Editorial auth header — distinctive two-tone typography with an accent bar.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.titleTop,
    required this.titleAccent,
    required this.subtitle,
    this.eyebrow = 'Business CRM',
  });

  final String titleTop;
  final String titleAccent;
  final String subtitle;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow pill with animated-style dot
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.ink],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.3,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Two-line contrasting headline (cross-fades smoothly in place)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topLeft,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: Column(
            key: ValueKey('$titleTop|$titleAccent'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleTop,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  height: 1.05,
                  letterSpacing: -1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0A5E65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  titleAccent,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Signature underline bar (stays stationary)
        Row(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: Text(
              subtitle,
              key: ValueKey(subtitle),
              style: TextStyle(
                fontSize: 14.5,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
