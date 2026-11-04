import 'package:flutter/material.dart';

/// Centralized color tokens for Business Manager.
/// Never hardcode colors outside this file.
class AppColors {
  AppColors._();

  // ─── Brand — Indigo ───────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryDeep = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primarySubtle = Color(0xFFEEF2FF);
  static const Color primaryContainer = Color(0xFFE0E7FF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ─── Semantic — Financial ─────────────────────────────────────────────────
  static const Color income = Color(0xFF10B981);
  static const Color incomeLight = Color(0xFF34D399);
  static const Color incomeDark = Color(0xFF059669);
  static const Color incomeBackground = Color(0xFFD1FAE5);

  static const Color expense = Color(0xFFF43F5E);
  static const Color expenseLight = Color(0xFFFB7185);
  static const Color expenseDark = Color(0xFFE11D48);
  static const Color expenseBackground = Color(0xFFFFE4E6);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningBackground = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFF87171);

  // ─── Neutral — Slate ──────────────────────────────────────────────────────
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate800 = Color(0xFF1E293B);

  // ─── Light Theme ──────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F3F9);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF181A25);
  static const Color lightTextSecondary = Color(0xFF667085);
  static const Color lightTextMuted = Color(0xFF98A2B3);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightDivider = Color(0xFFEEF0F4);

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF101116);
  static const Color darkSurface = Color(0xFF191B25);
  static const Color darkSurfaceSecondary = Color(0xFF222530);
  static const Color darkSurfaceElevated = Color(0xFF292C39);
  static const Color darkPrimary = Color(0xFF818CF8);
  static const Color darkPrimaryContainer = Color(0xFF292B50);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFA1A1B2);
  static const Color darkTextMuted = Color(0xFF74788B);
  static const Color darkBorder = Color(0xFF303341);
  static const Color darkDivider = Color(0xFF282B36);
}

/// Semantic colors exposed via ThemeExtension — use these in widgets.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.income,
    required this.incomeBackground,
    required this.expense,
    required this.expenseBackground,
    required this.warning,
    required this.warningBackground,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color income;
  final Color incomeBackground;
  final Color expense;
  final Color expenseBackground;
  final Color warning;
  final Color warningBackground;
  final Color danger;

  static const light = AppSemanticColors(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceSecondary: AppColors.lightSurfaceSecondary,
    surfaceElevated: AppColors.lightSurfaceElevated,
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    onPrimary: AppColors.onPrimary,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    border: AppColors.lightBorder,
    divider: AppColors.lightDivider,
    income: AppColors.income,
    incomeBackground: AppColors.incomeBackground,
    expense: AppColors.expense,
    expenseBackground: AppColors.expenseBackground,
    warning: AppColors.warning,
    warningBackground: AppColors.warningBackground,
    danger: AppColors.danger,
  );

  static const dark = AppSemanticColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceSecondary: AppColors.darkSurfaceSecondary,
    surfaceElevated: AppColors.darkSurfaceElevated,
    primary: AppColors.darkPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimary: AppColors.onPrimary,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    border: AppColors.darkBorder,
    divider: AppColors.darkDivider,
    income: AppColors.incomeLight,
    incomeBackground: Color(0xFF064E3B),
    expense: AppColors.expenseLight,
    expenseBackground: Color(0xFF4C0519),
    warning: AppColors.warningLight,
    warningBackground: Color(0xFF451A03),
    danger: AppColors.dangerLight,
  );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? surfaceElevated,
    Color? primary,
    Color? primaryContainer,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? income,
    Color? incomeBackground,
    Color? expense,
    Color? expenseBackground,
    Color? warning,
    Color? warningBackground,
    Color? danger,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      income: income ?? this.income,
      incomeBackground: incomeBackground ?? this.incomeBackground,
      expense: expense ?? this.expense,
      expenseBackground: expenseBackground ?? this.expenseBackground,
      warning: warning ?? this.warning,
      warningBackground: warningBackground ?? this.warningBackground,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeBackground: Color.lerp(incomeBackground, other.incomeBackground, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseBackground: Color.lerp(expenseBackground, other.expenseBackground, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBackground: Color.lerp(warningBackground, other.warningBackground, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Convenience extension to access semantic colors from BuildContext.
extension AppColorsContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
