import 'package:flutter/services.dart';

/// The phone's own unlock sheet (fingerprint, falling back to the screen
/// lock), from MainActivity.kt.
class LockBridge {
  static const _channel = MethodChannel('auto_spend/sms');

  /// Whether the phone has a screen lock to ask for.
  static Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('lockAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Shows the sheet; true once the user is through.
  static Future<bool> unlock() async {
    try {
      return await _channel.invokeMethod<bool>('unlock') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
