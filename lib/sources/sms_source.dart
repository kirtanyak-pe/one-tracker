import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../engine/ingest.dart';
import '../model/transaction.dart';

/// Reads bank SMS from the Android inbox. Catches up on anything that
/// arrived while the app wasn't running.
abstract final class SmsSource {
  static const _channel = MethodChannel('auto_spend/sms');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() async => isSupported && await Permission.sms.isGranted;

  static Future<bool> requestPermission() async =>
      isSupported && (await Permission.sms.request()).isGranted;

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
          sourceId: r['id'] as String,
          sender: r['sender'] as String,
          body: (r['body'] as String?) ?? '',
          at: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
        ),
    ];
  }
}
