import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient() {
  try {
    if (Platform.isIOS || Platform.isMacOS) {
      final config = URLSessionConfiguration.ephemeralSessionConfiguration()
        ..timeoutIntervalForRequest = const Duration(seconds: 15);
      return CupertinoClient.fromSessionConfiguration(config);
    }
  } catch (_) {}
  final io = HttpClient()
    ..idleTimeout = const Duration(seconds: 90)
    ..connectionTimeout = const Duration(seconds: 8)
    ..autoUncompress = true;
  return IOClient(io);
}
