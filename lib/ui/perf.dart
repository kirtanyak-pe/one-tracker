import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lite mode for low-end phones: no animations (via MediaQuery
/// disableAnimations, which Motion honours) and no blurred shadows.
abstract final class Perf {
  /// Read by [Shadows]; set by AppController from the device + setting.
  static bool lite = false;

  static const _channel = MethodChannel('auto_spend/sms');

  /// True on Android "low RAM" devices or phones with < 4.5 GB RAM.
  static Future<bool> isLowEndDevice() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final d = await _channel.invokeMapMethod<String, Object?>('deviceClass') ?? const {};
      final lowRam = d['lowRam'] == true;
      final memMb = (d['totalMemMb'] as int?) ?? 8192;
      return lowRam || memMb < 4608;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
