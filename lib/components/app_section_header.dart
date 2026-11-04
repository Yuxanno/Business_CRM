import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: action,
            child: Text(
              actionLabel ?? 'Все',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
