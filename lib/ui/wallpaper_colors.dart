import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The wallpaper's key colour (Android 12+ Material You), or null where the
/// system doesn't offer one. Only the seed is taken from dynamic_color — its
/// ColorScheme is a different type from Flutter's; Flutter's own
/// ColorScheme.fromSeed builds the same tonal palette from it.
Future<Color?> wallpaperSeed() async {
  if (kIsWeb) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) return Color(palette.primary.get(40));
    return await DynamicColorPlugin.getAccentColor();
  } catch (_) {
    return null;
  }
}
