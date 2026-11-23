// Picks the fastest available HTTP stack per platform:
// * Android  → Cronet (HTTP/2 + QUIC, Chrome's network stack)
// * iOS/macOS → NSURLSession (cupertino_http)
// * Web      → browser fetch
// * Fallback → dart:io with long-lived keep-alive connections
export 'http_client_factory_stub.dart'
    if (dart.library.io) 'http_client_factory_io.dart';
