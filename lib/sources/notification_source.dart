import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../engine/ingest.dart';
import '../model/transaction.dart';

/// Live payment notifications from UPI and bank apps (Android only). Also
/// catches bank SMS the moment they arrive, via the SMS app's notification.
class NotificationSource {
  NotificationSource(this.onMessage);

  final void Function(RawMessage message) onMessage;
  StreamSubscription<ServiceNotificationEvent>? _subscription;

  static const _ownPackage = 'com.autosplit.auto_split';

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async =>
      isSupported && await NotificationListenerService.isPermissionGranted();

  /// Opens Android's "Notification access" settings page.
  static Future<bool> requestPermission() async =>
      isSupported && await NotificationListenerService.requestPermission();

  void start() {
    if (!isSupported || _subscription != null) return;
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      if (event.hasRemoved || event.packageName == _ownPackage) return;
      final now = DateTime.now();
      onMessage(RawMessage(
        source: Source.notification,
        sourceId: '${event.packageName}:${event.id}:${now.millisecondsSinceEpoch ~/ 60000}',
        sender: event.packageName,
        body: '${event.title}\n${event.content}',
        at: now,
      ));
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
