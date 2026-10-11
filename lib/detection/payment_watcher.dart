import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

/// Listens to every notification on the phone (Android only) and forwards
/// the text of anything that might be a payment. Parsing lives elsewhere.
class PaymentWatcher {
  PaymentWatcher(this.onNotificationText);

  final void Function(String packageName, String text) onNotificationText;
  StreamSubscription<ServiceNotificationEvent>? _subscription;

  static const _ownPackage = 'com.autosplit.auto_split';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async =>
      isSupported && await NotificationListenerService.isPermissionGranted();

  /// Opens Android's "Notification access" settings page.
  static Future<bool> requestPermission() async =>
      isSupported && await NotificationListenerService.requestPermission();

  void start() {
    if (!isSupported || _subscription != null) return;
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      if (event.hasRemoved || event.packageName == _ownPackage) return;
      onNotificationText(event.packageName, '${event.title}\n${event.content}');
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
