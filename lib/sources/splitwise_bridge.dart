import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../split/pending_actions.dart';

/// Android side of the Splitwise hand-off (SplitwiseLauncher.kt,
/// SplitNotifications.kt). Everything is a no-op elsewhere (tests, web).
abstract final class SplitwiseBridge {
  static const _channel = MethodChannel('auto_spend/sms');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens Splitwise's Add expense screen with the payment filled in. If
  /// Splitwise isn't installed its Play Store page opens and this is false.
  static Future<bool> open({required int amountMinor, required String payee, int? groupId}) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openSplitwise', {
            'amountMinor': amountMinor,
            'payee': payee,
            'groupId': ?groupId,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Opening Splitwise failed: ${e.message}');
      return false;
    }
  }

  /// Posts "₹450 · Swiggy — tap to split it in Splitwise". Works from the
  /// background SMS engine too.
  static Future<void> showNotification({
    required String txnId,
    required int amountMinor,
    required String payee,
    int? groupId,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('showSplitNotification', {
        'txnId': txnId,
        'amountMinor': amountMinor,
        'payee': payee,
        'groupId': ?groupId,
      });
    } on PlatformException catch (e) {
      debugPrint('Split notification failed: ${e.message}');
    }
  }

  /// What was pressed on split notifications since last asked; the queue is
  /// emptied.
  static Future<List<PendingSplitAction>> takePendingActions() async {
    if (!isSupported) return const [];
    try {
      return PendingSplitAction.parseAll(await _channel.invokeMethod<List<Object?>>('takePendingSplitActions'));
    } on PlatformException catch (e) {
      debugPrint('Reading split actions failed: ${e.message}');
      return const [];
    }
  }
}
