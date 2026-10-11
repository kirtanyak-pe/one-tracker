import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Posts budget alerts as phone notifications (Android only).
abstract final class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Android 13+ asks the user; older versions return true.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> show(int id, String title, String body) async {
    if (!isSupported) return;
    await _init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          'Budget alerts',
          channelDescription: 'When you reach 80% or 100% of a budget',
          importance: Importance.high,
        ),
      ),
    );
  }
}
