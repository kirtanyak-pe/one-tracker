import 'package:flutter/material.dart';

/// Theme choices. Default: follow the system for light/dark, and take
/// colours from the wallpaper (Material You) where Android offers them.
/// Animations and soft effects.
enum Effects { auto, reduced, full }

class Appearance {
  const Appearance({this.mode = ThemeMode.system, this.wallpaperColors = true, this.effects = Effects.auto});

  final ThemeMode mode;

  /// false = One Tracker's own orange.
  final bool wallpaperColors;

  /// auto = reduced on low-end phones, full elsewhere.
  final Effects effects;

  Appearance copyWith({ThemeMode? mode, bool? wallpaperColors, Effects? effects}) => Appearance(
        mode: mode ?? this.mode,
        wallpaperColors: wallpaperColors ?? this.wallpaperColors,
        effects: effects ?? this.effects,
      );

  factory Appearance.fromJson(Map<String, dynamic> j) => Appearance(
        mode: ThemeMode.values.byName((j['mode'] as String?) ?? 'system'),
        wallpaperColors: (j['wallpaperColors'] as bool?) ?? true,
        effects: Effects.values.byName((j['effects'] as String?) ?? 'auto'),
      );

  Map<String, dynamic> toJson() => {'mode': mode.name, 'wallpaperColors': wallpaperColors, 'effects': effects.name};
}
