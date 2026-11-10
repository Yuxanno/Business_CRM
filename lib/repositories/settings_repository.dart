import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/api_client.dart';

/// Persists AppSettings in SharedPreferences.
class SettingsRepository {
  static const _prefix = 'settings_';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
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
    
    // Попытка синхронизации с сервером в фоне (не блокирует возврат)
    _syncFromServer(prefs);
    
    return settings;
  }
  
  /// Синхронизирует настройки с сервера в фоновом режиме
  Future<void> _syncFromServer(SharedPreferences prefs) async {
    try {
      final token = prefs.getString('authToken');
      if (token == null || token.isEmpty) return;
      
      final data = await ApiClient.instance.get('/api/auth/me');
      if (data is Map) {
        final currency = data['currency']?.toString();
        final locale = data['locale']?.toString();
        
        if (currency != null && currency.isNotEmpty) {
          await prefs.setString('${_prefix}currency', currency);
        }
        if (locale != null && locale.isNotEmpty) {
          await prefs.setString('${_prefix}locale', locale);
        }
      }
    } catch (e) {
      // Тихо игнорируем ошибки синхронизации
    }
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

      final currentSettings = await load();
      
      await ApiClient.instance.put('/api/auth/profile', {
        'currency': currency ?? currentSettings.currency,
        'locale': locale ?? currentSettings.locale,
      });
    } catch (e) {
      // Rethrow so the caller can handle it
      throw Exception('Failed to sync to server: $e');
    }
  }
}
