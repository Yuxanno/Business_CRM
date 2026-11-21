import 'dart:js_interop';

@JS('Notification')
extension type _JsNotification._(JSObject _) implements JSObject {
  external factory _JsNotification(String title, _JsNotificationOptions options);

  @JS('permission')
  external static String get permission;

  @JS('requestPermission')
  external static JSPromise<JSString> requestPermission();
}

extension type _JsNotificationOptions._(JSObject _) implements JSObject {
  external factory _JsNotificationOptions({String body});
}

Future<void> initPlatformNotifications() async {}

Future<bool> requestPlatformNotificationPermission() async {
  try {
    final current = _JsNotification.permission;
    if (current == 'granted') return true;
    if (current == 'denied') return false;
    final result = await _JsNotification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> cancelAllPlatformNotifications() async {}

Future<void> showPlatformNotification({
  required int id,
  required String title,
  required String body,
}) async {
  try {
    if (_JsNotification.permission == 'granted') {
      _JsNotification(title, _JsNotificationOptions(body: body));
    }
  } catch (_) {}
}

Future<void> schedulePlatformNotification({
  required int id,
  required String title,
  required String body,
  required DateTime localScheduledAt,
}) async {
  // Browsers do not support background OS-level scheduling via Notification API.
}
