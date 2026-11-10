import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'app_skeleton.dart';

/// Отображает текст с валютой, показывая skeleton пока данные загружаются
class CurrencyText extends StatelessWidget {
  const CurrencyText({
    super.key,
    required this.text,
    this.style,
    this.skeletonWidth = 60,
    this.skeletonHeight = 14,
  });

  final String text;
  final TextStyle? style;
  final double skeletonWidth;
  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    
    if (settingsProvider.isLoading) {
      return AppSkeleton(
        width: skeletonWidth,
        height: skeletonHeight,
        radius: 4,
      );
    }

    return Text(text, style: style);
  }
}

/// Получает валюту из SettingsProvider с учетом загрузки
String getCurrency(BuildContext context) {
  final settingsProvider = context.watch<SettingsProvider>();
  return settingsProvider.currency;
}

/// Проверяет, загружаются ли настройки
bool isSettingsLoading(BuildContext context) {
  final settingsProvider = context.watch<SettingsProvider>();
  return settingsProvider.isLoading;
}
