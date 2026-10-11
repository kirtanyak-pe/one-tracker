import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/widget_data.dart';

/// Hands today/week/month figures to the Android home-screen widget.
abstract final class WidgetBridge {
  static const _channel = MethodChannel('auto_spend/sms');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> push(Map<String, WidgetPeriod> periods) async {
    if (!isSupported) return;
    final json = jsonEncode({
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'periods': {for (final e in periods.entries) e.key: e.value.toJson()},
    });
    try {
      await _channel.invokeMethod('widget', {'json': json});
    } on PlatformException catch (e) {
      debugPrint('Widget update failed: ${e.message}');
    }
  }

  /// Asks the launcher to add the widget (it shows its own confirmation).
  /// False when the launcher can't do that — add it from the widget list.
  static Future<bool> requestPin() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('pinWidget') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
