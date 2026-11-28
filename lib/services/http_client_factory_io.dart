import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient() {
  final io = HttpClient()
    ..idleTimeout = const Duration(seconds: 90)
    ..connectionTimeout = const Duration(seconds: 8)
    ..autoUncompress = true;
  return IOClient(io);
}
