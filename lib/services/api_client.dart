import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_tr.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client for the BizFlow API.
/// Uses a persistent keep-alive [http.Client], caches the JWT in memory,
/// and applies strict request timeouts so UI never stalls on slow networks.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _requestTimeout = Duration(seconds: 25);
  static const String _defaultRenderUrl = 'https://business-crm-da1s.onrender.com';

  final http.Client _client = http.Client();
  String? _cachedToken;
  bool _tokenLoaded = false;
  Timer? _keepAliveTimer;
  bool _pingInFlight = false;

  // Simple ETag cache per GET path so unchanged responses can return 304
  final Map<String, String> _etags = {};
  final Map<String, dynamic> _etagPayloads = {};

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb && Uri.base.host == 'business-crm-da1s.onrender.com') {
      return '';
    }
    return _defaultRenderUrl;
  }

  /// Sends a lightweight /health ping every 5 seconds so the Render backend stays warm.
  void startKeepAlive() {
    if (_keepAliveTimer != null) return;
    _pingHealth();
    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pingHealth(),
    );
  }

  void stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> _pingHealth() async {
    if (_pingInFlight) return;
    _pingInFlight = true;
    try {
      await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
    } finally {
      _pingInFlight = false;
    }
  }

  void setToken(String? token) {
    _cachedToken = (token != null && token.isNotEmpty) ? token : null;
    _tokenLoaded = true;
  }

  void clearSessionCache() {
    _cachedToken = null;
    _tokenLoaded = true;
    _etags.clear();
    _etagPayloads.clear();
  }

  Future<Map<String, String>> _headers({String? etag}) async {
    if (!_tokenLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('authToken');
      _tokenLoaded = true;
    }
    return {
      'Content-Type': 'application/json',
      'Accept-Language': AppTr.isEn ? 'en' : 'ru',
      if (_cachedToken != null && _cachedToken!.isNotEmpty)
        'Authorization': 'Bearer $_cachedToken',
      if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
    };
  }

  /// Resources whose cached GET responses may change after a write to [path].
  /// Unknown paths fall back to dropping everything (safe default).
  static const _dependents = <String, List<String>>{
    '/api/orders': ['/api/orders', '/api/customers', '/api/dashboard', '/api/transactions', '/api/debts'],
    '/api/customers': ['/api/customers', '/api/orders', '/api/dashboard', '/api/debts'],
    '/api/transactions': ['/api/transactions', '/api/dashboard', '/api/orders', '/api/customers', '/api/debts'],
    '/api/debts': ['/api/debts', '/api/transactions', '/api/dashboard', '/api/customers'],
  };

  void _invalidateFor(String path) {
    List<String>? prefixes;
    for (final e in _dependents.entries) {
      if (path.startsWith(e.key)) {
        prefixes = e.value;
        break;
      }
    }
    if (prefixes == null) {
      _etags.clear();
      _etagPayloads.clear();
      return;
    }
    bool hit(String k) => prefixes!.any(k.startsWith);
    _etags.removeWhere((k, _) => hit(k));
    _etagPayloads.removeWhere((k, _) => hit(k));
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);
  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body);

  /// Sends raw binary bytes (e.g. recorded audio) without invalidating CRUD caches.
  Future<dynamic> postBinary(
    String path,
    Uint8List bytes, {
    required String contentType,
    String? filename,
    String? language,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_tokenLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('authToken');
      _tokenLoaded = true;
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': contentType,
      'Accept-Language': AppTr.isEn ? 'en' : 'ru',
      if (_cachedToken != null && _cachedToken!.isNotEmpty)
        'Authorization': 'Bearer $_cachedToken',
      if (filename != null && filename.isNotEmpty)
        'X-Audio-Filename': filename,
      if (language != null && language.isNotEmpty)
        'X-Audio-Language': language,
    };

    final response =
        await _client.post(uri, headers: headers, body: bytes).timeout(timeout);

    dynamic decoded;
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final rawMessage = decoded is Map && decoded['error'] != null
        ? decoded['error'].toString()
        : AppTr.tr('Ошибка сервера (${response.statusCode})',
            'Server error (${response.statusCode})');
    throw ApiException(
      _localizeServerError(rawMessage),
      statusCode: response.statusCode,
    );
  }

  Future<dynamic> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$baseUrl$path');
    final isGet = method == 'GET';
    final headers = await _headers(etag: isGet ? _etags[path] : null);

    late http.Response response;
    switch (method) {
      case 'POST':
        _invalidateFor(path);
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout);
      case 'PUT':
        _invalidateFor(path);
        response = await _client
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout);
      case 'DELETE':
        _invalidateFor(path);
        response = await _client
            .delete(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_requestTimeout);
      default:
        response =
            await _client.get(uri, headers: headers).timeout(_requestTimeout);
    }

    if (isGet && response.statusCode == 304 && _etagPayloads.containsKey(path)) {
      return _etagPayloads[path];
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (isGet) {
        final etag = response.headers['etag'];
        if (etag != null && etag.isNotEmpty && decoded != null) {
          _etags[path] = etag;
          _etagPayloads[path] = decoded;
        }
      }
      return decoded;
    }

    final rawMessage = decoded is Map && decoded['error'] != null
        ? decoded['error'].toString()
        : AppTr.tr('Ошибка сервера (${response.statusCode})',
            'Server error (${response.statusCode})');
    final message = _localizeServerError(rawMessage);
    throw ApiException(message, statusCode: response.statusCode);
  }

  static const _serverErrorEn = <String, String>{
    'Укажите имя, логин и пароль': 'Enter name, username, and password',
    'Пользователь с таким логином уже существует':
        'An account with this username already exists',
    'Некорректные данные пользователя': 'Invalid user data',
    'Укажите логин и пароль': 'Enter username and password',
    'Неверный логин или пароль': 'Invalid username or password',
    'Пользователь не найден': 'User not found',
    'Укажите имя пользователя': 'Enter owner name',
    'Логин: 3–32 символа, латиница, цифры, . _ -':
        'Username: 3–32 chars, letters, digits, . _ -',
    'Новый пароль — минимум 6 символов':
        'New password must be at least 6 characters',
    'Введите пароль для подтверждения': 'Enter your password to confirm',
    'Неверный пароль': 'Incorrect password',
    'Не авторизован — токен отсутствует': 'Unauthorized — token missing',
    'Неверный токен': 'Invalid token',
    'Клиент не найден': 'Customer not found',
    'Укажите имя': 'Enter name',
    'Долг не найден': 'Debt not found',
    'Укажите имя, направление и сумму': 'Enter name, direction, and amount',
    'Некорректная сумма': 'Invalid amount',
    'Заказ не найден': 'Order not found',
    'Укажите название и клиента': 'Enter title and customer',
    'Укажите сумму, тип и дату': 'Enter amount, type, and date',
    'Операция не найдена': 'Transaction not found',
    'Голосовой ввод не настроен (добавьте GROQ_API_KEY в .env)':
        'Voice input is not configured (add GROQ_API_KEY to .env)',
    'Запись слишком короткая — попробуйте ещё раз':
        'Recording is too short — please try again',
    'Неверный ключ GROQ_API_KEY': 'Invalid GROQ_API_KEY',
    'Лимит запросов Groq временно исчерпан, попробуйте через минуту':
        'Groq rate limit reached, please try again in a minute',
    'Ошибка распознавания речи': 'Speech recognition failed',
    'Не удалось связаться с сервисом распознавания речи':
        'Could not reach speech recognition service',
  };

  static String _localizeServerError(String message) {
    if (!AppTr.isEn) return message;
    return _serverErrorEn[message] ?? message;
  }
}
