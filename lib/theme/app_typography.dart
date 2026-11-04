import 'package:flutter/material.dart';

/// Typography scale for Business Manager.
/// Uses system fonts: SF Pro on iOS, Roboto on Android.
class AppTypography {
  AppTypography._();

  /// 30–32px bold — large financial values
  static const TextStyle financialLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 23–24px bold — screen titles
  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// 17–18px semibold — section headings
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// 15–16px semibold — card titles
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// 16–20px semibold — financial card values
  static const TextStyle financialCard = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 14–15px regular — main body text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 12–13px regular — secondary text
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 11px medium — captions and labels
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// 14px medium — button labels
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}
