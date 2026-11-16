import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/local_cache.dart';
import '../../l10n/app_tr.dart';

class AccountInfo {
  const AccountInfo({
    required this.name,
    required this.login,
    this.businessName = '',
    this.currency,
    this.locale,
  });

  final String name;
  final String login;
  final String businessName;
  /// Null means the server didn't return a value — caller should not override.
  final String? currency;
  final String? locale;
}

class AccountStore {
  static Future<AccountInfo> load() async {
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString('userName') ?? '';
    var login = prefs.getString('userLogin') ?? '';
    var businessName = '';
    String? currency;
    String? locale;

    try {
      final data = await ApiClient.instance.get('/api/auth/me');
      if (data is Map) {
        name = (data['name'] ?? name).toString();
        login = (data['username'] ?? login).toString();
        businessName = (data['businessName'] ?? '').toString();
        // Only set if server returned a non-empty value
        final serverCurrency = data['currency']?.toString();
        final serverLocale = data['locale']?.toString();
        if (serverCurrency != null && serverCurrency.isNotEmpty) {
          currency = serverCurrency;
        }
        if (serverLocale != null && serverLocale.isNotEmpty) {
          locale = serverLocale;
        }
        await prefs.setString('userName', name);
        await prefs.setString('userLogin', login);
      }
    } catch (_) {}

    return AccountInfo(
      name: name,
      login: login,
      businessName: businessName,
      currency: currency,
      locale: locale,
    );
  }

  static Future<void> remember({
    required String name,
    required String login,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userLogin', login);
  }

  /// Saves the account on the server. Returns an error message, or null.
  static Future<String?> updateProfile({
    required String name,
    required String login,
    required String businessName,
    required String password,
    required String currency,
    required String locale,
  }) async {
    try {
      final data = await ApiClient.instance.put('/api/auth/profile', {
        'name': name,
        'username': login,
        'businessName': businessName,
        'currency': currency,
        'locale': locale,
        if (password.isNotEmpty) 'password': password,
      });
      if (data is Map) {
        await remember(
          name: (data['name'] ?? name).toString(),
          login: (data['username'] ?? login).toString(),
        );
      } else {
        await remember(name: name, login: login);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return AppTr.tr(
        'Не удалось сохранить. Проверьте, что сервер запущен.',
        'Failed to save. Make sure the server is running.',
      );
    }
  }

  /// Permanently deletes the account and all its data on the server
  /// after verifying [password]. Returns an error message, or null on success.
  static Future<String?> deleteAccount({required String password}) async {
    try {
      await ApiClient.instance.delete(
        '/api/auth/account',
        {'password': password},
      );
      await clearSession();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return AppTr.tr(
        'Не удалось удалить аккаунт. Проверьте, что сервер запущен.',
        'Failed to delete account. Make sure the server is running.',
      );
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userName');
    await prefs.remove('userLogin');
    ApiClient.instance.clearSessionCache();
    await LocalCache.clearAll();
  }
}
