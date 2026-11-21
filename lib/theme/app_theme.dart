import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static const List<String> _fontFallback = [
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static TextStyle _font({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamilyFallback: _fontFallback,
    );
  }

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        semantics: AppSemanticColors.light,
        systemUiOverlayStyle: SystemUiOverlayStyle.dark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppSemanticColors semantics,
    required SystemUiOverlayStyle systemUiOverlayStyle,
  }) {
    final isLight = brightness == Brightness.light;
    final baseText = Typography.material2021().black;

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

    TextStyle styled(
      TextStyle? base, {
      double? size,
      FontWeight? weight,
      Color? color,
      double? letterSpacing,
      double? height,
    }) {
      return (base ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? semantics.textPrimary,
        letterSpacing: letterSpacing,
        height: height,
        fontFamilyFallback: _fontFallback,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: semantics.background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothFadePageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothFadePageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothFadePageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothFadePageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothFadePageTransitionsBuilder(),
        },
      ),
      extensions: [semantics],
      textTheme: baseText.copyWith(
        displayLarge: styled(baseText.displayLarge,
            size: 30, weight: FontWeight.w800, letterSpacing: -1),
        titleLarge: styled(baseText.titleLarge,
            size: 24, weight: FontWeight.w800, letterSpacing: -0.6),
        titleMedium: styled(baseText.titleMedium,
            size: 17, weight: FontWeight.w700),
        titleSmall: styled(baseText.titleSmall,
            size: 15, weight: FontWeight.w700),
        bodyLarge: styled(baseText.bodyLarge, size: 15),
        bodyMedium: styled(baseText.bodyMedium, size: 14),
        bodySmall: styled(baseText.bodySmall,
            size: 12, color: semantics.textSecondary),
        labelSmall: styled(baseText.labelSmall,
            size: 11, weight: FontWeight.w600, color: semantics.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: semantics.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemUiOverlayStyle,
        titleTextStyle: _font(
          color: semantics.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: semantics.textPrimary),
      ),
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: semantics.surface,
        selectedItemColor: semantics.primary,
        unselectedItemColor: semantics.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: _font(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: _font(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: semantics.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantics.surfaceSecondary,
        selectedColor: semantics.primaryContainer,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: semantics.textSecondary,
        ),
        side: BorderSide(color: semantics.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: semantics.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        titleTextStyle: _font(
          color: semantics.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: _font(
          color: semantics.textSecondary,
          fontSize: 12,
        ),
        iconColor: semantics.textSecondary,
      ),
    );
  }
}

/// Silky page transition: gentle 2.5% horizontal glide paired with an
/// accelerated fade-in so pushes feel crisp without overlapping heavy sheets.
class _SmoothFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.025, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
