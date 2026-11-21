import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();
bool _initialized = false;

const String _channelId = 'bizflow_reminders';
const String _channelName = 'BizFlow Reminders';
const String _channelDesc =
    'Reminders for upcoming and overdue debts and order payments';

Future<void> initPlatformNotifications() async {
  if (_initialized) return;
  tz_data.initializeTimeZones();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
    macOS: darwinSettings,
  );

  await _plugin.initialize(settings);
  _initialized = true;
}

Future<bool> requestPlatformNotificationPermission() async {
  await initPlatformNotifications();

  if (Platform.isAndroid) {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  if (Platform.isIOS) {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  if (Platform.isMacOS) {
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final granted = await mac?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  return true;
}

Future<void> cancelAllPlatformNotifications() async {
  if (!_initialized) return;
  await _plugin.cancelAll();
}

NotificationDetails _platformDetails() {
  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
  );
  const darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  return const NotificationDetails(
    android: androidDetails,
    iOS: darwinDetails,
    macOS: darwinDetails,
  );
}

Future<void> showPlatformNotification({
  required int id,
  required String title,
  required String body,
}) async {
  await initPlatformNotifications();
  await _plugin.show(id, title, body, _platformDetails());
}

Future<void> schedulePlatformNotification({
  required int id,
  required String title,
  required String body,
  required DateTime localScheduledAt,
}) async {
  await initPlatformNotifications();
  if (!localScheduledAt.isAfter(DateTime.now())) return;

  final utcTarget = localScheduledAt.toUtc();
  final tzDate = tz.TZDateTime.from(utcTarget, tz.UTC);

  await _plugin.zonedSchedule(
    id,
    title,
    body,
    tzDate,
    _platformDetails(),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

