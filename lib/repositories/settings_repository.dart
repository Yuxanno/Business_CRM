import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/api_client.dart';

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
      themeMode: prefs.getString('${_prefix}themeMode') ?? 'light',
      dateFormat:
          prefs.getString('${_prefix}dateFormat') ?? 'dd.MM.yyyy',
      isOnboardingDone:
          prefs.getBool('${_prefix}isOnboardingDone') ?? false,
    );
  }

  /// Fetches the user's saved profile settings (currency, locale, name, businessName) from the server.
  Future<Map<String, String>?> fetchServerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null || token.isEmpty) return null;

      final data = await ApiClient.instance.get('/api/auth/me');
      if (data is Map) {
        return {
          if (data['currency'] != null &&
              data['currency'].toString().isNotEmpty)
            'currency': data['currency'].toString(),
          if (data['locale'] != null && data['locale'].toString().isNotEmpty)
            'locale': data['locale'].toString(),
          if (data['businessName'] != null)
            'businessName': data['businessName'].toString(),
          if (data['name'] != null && data['name'].toString().isNotEmpty)
            'ownerName': data['name'].toString(),
        };
      }
    } catch (_) {
      // Ignore offline/network sync errors
    }
    return null;
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

  /// Syncs currency and/or locale to the server via /api/auth/profile
  Future<void> syncToServer({String? currency, String? locale}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null || token.isEmpty) {
        // User not logged in, skip sync
        return;
      }

      final currentCurrency = prefs.getString('${_prefix}currency') ?? 'RUB';
      final currentLocale = prefs.getString('${_prefix}locale') ?? 'ru';

      await ApiClient.instance.put('/api/auth/profile', {
        'currency': currency ?? currentCurrency,
        'locale': locale ?? currentLocale,
      });
    } catch (e) {
      // Rethrow so the caller can handle it
      throw Exception('Failed to sync to server: $e');
    }
  }
}
