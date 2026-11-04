import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        semantics: AppSemanticColors.light,
        systemUiOverlayStyle: SystemUiOverlayStyle.dark,
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        semantics: AppSemanticColors.dark,
        systemUiOverlayStyle: SystemUiOverlayStyle.light,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppSemanticColors semantics,
    required SystemUiOverlayStyle systemUiOverlayStyle,
  }) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: semantics.primary,
      onPrimary: semantics.onPrimary,
      primaryContainer: semantics.primaryContainer,
      onPrimaryContainer: semantics.primary,
      secondary: semantics.primary,
      onSecondary: semantics.onPrimary,
      secondaryContainer: semantics.primaryContainer,
      onSecondaryContainer: semantics.primary,
      tertiary: semantics.warning,
      onTertiary: Colors.white,
      tertiaryContainer: semantics.warningBackground,
      onTertiaryContainer: semantics.warning,
      error: semantics.danger,
      onError: Colors.white,
      errorContainer: semantics.expenseBackground,
      onErrorContainer: semantics.expense,
      surface: semantics.surface,
      onSurface: semantics.textPrimary,
      surfaceContainerHighest: semantics.surfaceSecondary,
      onSurfaceVariant: semantics.textSecondary,
      outline: semantics.border,
      outlineVariant: semantics.divider,
      shadow: isLight ? Colors.black12 : Colors.black38,
      scrim: Colors.black54,
      inverseSurface: isLight ? AppColors.slate800 : AppColors.lightSurface,
      onInverseSurface: isLight ? Colors.white : AppColors.lightTextPrimary,
      inversePrimary: isLight ? AppColors.primaryLight : AppColors.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: semantics.background,
      extensions: [semantics],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: semantics.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemUiOverlayStyle,
        titleTextStyle: TextStyle(
          color: semantics.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: semantics.textPrimary),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: semantics.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: semantics.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantics.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantics.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantics.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantics.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantics.danger),
        ),
        labelStyle: TextStyle(color: semantics.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: semantics.textMuted, fontSize: 14),
        errorStyle: TextStyle(color: semantics.danger, fontSize: 12),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: semantics.surface,
        selectedItemColor: semantics.primary,
        unselectedItemColor: semantics.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: semantics.primary,
        foregroundColor: semantics.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: semantics.surfaceSecondary,
        selectedColor: semantics.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: semantics.textSecondary,
        ),
        side: BorderSide(color: semantics.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: semantics.divider,
        thickness: 1,
        space: 1,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        titleTextStyle: TextStyle(
          color: semantics.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: semantics.textSecondary,
          fontSize: 12,
        ),
        iconColor: semantics.textSecondary,
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: semantics.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: semantics.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: semantics.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: semantics.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: semantics.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: semantics.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: semantics.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: semantics.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
