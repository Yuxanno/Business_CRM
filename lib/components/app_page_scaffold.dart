import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_templates.dart';

/// Shared page chrome: editorial title + optional subtitle + actions + body.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.onRefresh,
    this.padding,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final scrollBody = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
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
            ),
          ),
        ),
        SliverPadding(
          padding: padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
          sliver: SliverToBoxAdapter(child: body),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );

    final child = onRefresh != null
        ? RefreshIndicator(
            color: colors.primary,
            onRefresh: onRefresh!,
            child: scrollBody,
          )
        : scrollBody;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: child),
    );
  }
}
