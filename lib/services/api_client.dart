import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client for the Biznes CRM API. Reads JWT from SharedPreferences.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3001';
    return 'http://localhost:3001';
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    late http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        response = await http.put(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        response = await http.get(uri, headers: headers);
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      decoded = jsonDecode(response.body);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map && decoded['error'] != null
        ? decoded['error'].toString()
        : 'Ошибка сервера (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
