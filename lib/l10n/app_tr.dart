import 'package:flutter/widgets.dart';

/// Global localization helper synced with [SettingsProvider].
///
/// Use `context.tr(ru, en)` inside widgets so `Localizations.localeOf(context)`
/// automatically triggers rebuilds whenever the app locale changes.
/// Use `AppTr.tr(ru, en)` in non-widget helpers (models, services, formatters).
class AppTr {
  AppTr._();

  static bool isEn = false;

  static String tr(String ru, String en) => isEn ? en : ru;
}

extension AppTrContext on BuildContext {
  bool get isEn {
    try {
      return Localizations.localeOf(this).languageCode == 'en';
    } catch (_) {
      return AppTr.isEn;
    }
  }

  String tr(String ru, String en) => isEn ? en : ru;
}

