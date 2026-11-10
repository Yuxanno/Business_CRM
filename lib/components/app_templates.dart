import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Compact labeled action for page headers.
class AppTextAction extends StatelessWidget {
  const AppTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: AppButtonVariant.text,
      isFullWidth: false,
      height: 36,
    );
  }
}

/// Shared title block: accent bar, title, one-line purpose.
class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = false,
    this.fallbackRoute,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else if (fallbackRoute != null) {
                context.go(fallbackRoute!);
              }
            },
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.2,
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...?actions,
      ],
    );
  }
}

/// List screen: title, purpose line, optional toolbar, then a flexible body.
class AppListPage extends StatelessWidget {
  const AppListPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.toolbar,
    this.showBack = false,
    this.fallbackRoute,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? toolbar;
  final Widget body;
  final bool showBack;
  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              ),
              child: AppPageTitle(
                title: title,
                subtitle: subtitle,
                actions: actions,
                showBack: showBack,
                fallbackRoute: fallbackRoute,
              ),
            ),
            if (toolbar != null) toolbar!,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Labeled money figure. Pass an already formatted amount.
class AppMoneyBlock extends StatelessWidget {
  const AppMoneyBlock({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.background,
    this.icon,
    this.caption,
  });

  final String label;
  final String amount;
  final Color color;
  final Color? background;
  final IconData? icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background ?? colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard list row: icon, title, secondary line, amount on the right.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
    this.badge,
    this.onTap,
    this.footer,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Widget? badge;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
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
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                badge!,
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: trailingColor ?? colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Detail header: back, name, status, main amount, actions.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.amountLabel,
    this.amount,
    this.amountColor,
    this.actions = const [],
    this.fallbackRoute,
  });

  final String title;
  final String? subtitle;
  final Widget? status;
  final String? amountLabel;
  final String? amount;
  final Color? amountColor;
  final List<Widget> actions;
  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else if (fallbackRoute != null) {
                  context.go(fallbackRoute!);
                }
              },
              icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
            color: colors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: AppSpacing.md),
          status!,
        ],
        if (amount != null) ...[
          const SizedBox(height: AppSpacing.lg),
          if (amountLabel != null)
            Text(
              amountLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          Text(
            amount!,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: amountColor ?? colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
