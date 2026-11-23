import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient() {
  try {
    if (Platform.isAndroid) {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.disabled,
        enableHttp2: true,
        enableQuic: true,
        enableBrotli: true,
        userAgent: 'BizFlow-Android',
      );
      return CronetClient.fromCronetEngine(engine, closeEngine: true);
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final config = URLSessionConfiguration.ephemeralSessionConfiguration()
        ..timeoutIntervalForRequest = const Duration(seconds: 15);
      return CupertinoClient.fromSessionConfiguration(config);
    }
  } catch (_) {
    // Cronet unavailable (e.g. no Google Play services) → dart:io fallback.
  }
  final io = HttpClient()
    ..idleTimeout = const Duration(seconds: 90)
    ..connectionTimeout = const Duration(seconds: 8)
    ..autoUncompress = true;
  return IOClient(io);
}
