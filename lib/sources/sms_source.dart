import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../engine/ingest.dart';
import '../model/transaction.dart';
import 'sms_id.dart';

/// Reads bank SMS from the Android inbox. Catches up on anything that
/// arrived while the app wasn't running.
abstract final class SmsSource {
  static const _channel = MethodChannel('auto_spend/sms');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async => isSupported && await Permission.sms.isGranted;

  static Future<bool> requestPermission() async =>
      isSupported && (await Permission.sms.request()).isGranted;

  /// READ_SMS and RECEIVE_SMS separately (both are in the SMS group).
  static Future<({bool read, bool receive})> permissions() async {
    if (!isSupported) return (read: false, receive: false);
    final m = await _channel.invokeMapMethod<String, bool>('smsPermissions') ?? const {};
    return (read: m['read'] ?? false, receive: m['receive'] ?? false);
  }

  /// Already allowed to read SMS? Then receiving is the same permission
  /// group, and Android grants it without asking again.
  static Future<void> upgradeToLive() async {
    final p = await permissions();
    if (p.read && !p.receive) await Permission.sms.request();
  }

  /// Bank SMS handed over by the native receiver while the app is running.
  static void listenLive(void Function(RawMessage message) onMessage) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'incoming') return;
      final args = Map<String, Object?>.from(call.arguments as Map);
      onMessage(liveMessage(
        sender: args['sender']! as String,
        body: args['body']! as String,
        at: DateTime.fromMillisecondsSinceEpoch(args['at']! as int),
      ));
    });
  }

  static RawMessage liveMessage({required String sender, required String body, required DateTime at}) =>
      RawMessage(source: Source.sms, sourceId: smsContentId(sender, body), sender: sender, body: body, at: at);

  /// Messages from bank-style senders newer than [since].
  static Future<List<RawMessage>> read({required DateTime since}) async {
    if (!await hasPermission()) return const [];
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'inbox',
      {'since': since.millisecondsSinceEpoch},
    );
    return [
      for (final r in rows ?? const <Map<dynamic, dynamic>>[])
        RawMessage(
          source: Source.sms,
          // By content, not inbox row: matches the copy that arrived live.
          sourceId: smsContentId(r['sender'] as String, (r['body'] as String?) ?? ''),
          sender: r['sender'] as String,
          body: (r['body'] as String?) ?? '',
          at: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
        ),
    ];
  }
}
