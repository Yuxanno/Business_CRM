import 'package:flutter/material.dart';

/// Centralized color tokens for Business Manager.
/// Never hardcode colors outside this file.
class AppColors {
  AppColors._();

  // ─── Brand — Deep Teal Ink ────────────────────────────────────────────────
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0D5F59);
  static const Color primaryDeep = Color(0xFF134E4A);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primarySubtle = Color(0xFFF0FDFA);
  static const Color primaryContainer = Color(0xFFCCFBF1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111827);

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
  static const Color lightBackground = Color(0xFFF3F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFE8F0EE);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextMuted = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFD5E0DC);
  static const Color lightDivider = Color(0xFFE5EDEA);
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
