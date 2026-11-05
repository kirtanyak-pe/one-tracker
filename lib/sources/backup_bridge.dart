import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android's file picker for backups (Storage Access Framework): the user
/// chooses where the file goes or comes from, so no storage permission.
abstract final class BackupBridge {
  static const _channel = MethodChannel('auto_spend/sms');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> appVersion() async {
    try {
      return await _channel.invokeMethod<String>('appVersion') ?? '';
    } on PlatformException {
      return '';
    }
  }

  /// Opens "save as"; true once written, false if the user backed out.
  static Future<bool> save(String name, String json) async =>
      await _channel.invokeMethod<bool>('backupSave', {
        'name': name,
        'json': json,
      }) ??
      false;

  /// Opens the file picker; the file's text, or null if the user backed out.
  static Future<String?> pick() => _channel.invokeMethod<String>('backupPick');
}
