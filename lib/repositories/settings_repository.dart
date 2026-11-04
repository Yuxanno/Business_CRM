import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Persists AppSettings in SharedPreferences.
class SettingsRepository {
  static const _prefix = 'settings_';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      businessName: prefs.getString('${_prefix}businessName') ?? '',
      ownerName: prefs.getString('${_prefix}ownerName') ?? '',
      currency: prefs.getString('${_prefix}currency') ?? 'RUB',
      locale: prefs.getString('${_prefix}locale') ?? 'ru',
      themeMode: prefs.getString('${_prefix}themeMode') ?? 'system',
      dateFormat:
          prefs.getString('${_prefix}dateFormat') ?? 'dd.MM.yyyy',
      isOnboardingDone:
          prefs.getBool('${_prefix}isOnboardingDone') ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '${_prefix}businessName', settings.businessName);
    await prefs.setString('${_prefix}ownerName', settings.ownerName);
    await prefs.setString('${_prefix}currency', settings.currency);
    await prefs.setString('${_prefix}locale', settings.locale);
    await prefs.setString('${_prefix}themeMode', settings.themeMode);
    await prefs.setString('${_prefix}dateFormat', settings.dateFormat);
    await prefs.setBool(
        '${_prefix}isOnboardingDone', settings.isOnboardingDone);
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}isOnboardingDone', true);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_prefix}isOnboardingDone') ?? false;
  }
}
