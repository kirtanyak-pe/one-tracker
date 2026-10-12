import 'package:flutter/material.dart';

/// Theme choices. Default: follow the system for light/dark, and take
/// colours from the wallpaper (Material You) where Android offers them.
class Appearance {
  const Appearance({this.mode = ThemeMode.system, this.wallpaperColors = true});

  final ThemeMode mode;

  /// false = Auto Spend's own orange.
  final bool wallpaperColors;

  Appearance copyWith({ThemeMode? mode, bool? wallpaperColors}) =>
      Appearance(mode: mode ?? this.mode, wallpaperColors: wallpaperColors ?? this.wallpaperColors);

  factory Appearance.fromJson(Map<String, dynamic> j) => Appearance(
        mode: ThemeMode.values.byName((j['mode'] as String?) ?? 'system'),
        wallpaperColors: (j['wallpaperColors'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {'mode': mode.name, 'wallpaperColors': wallpaperColors};
}
