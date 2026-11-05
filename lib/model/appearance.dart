import 'package:onyx/onyx.dart';

/// Theme choices. Default: follow the system for light/dark.
/// Animations and soft effects.
enum Effects { auto, reduced, full }

class Appearance {
  const Appearance({this.mode = OThemeMode.system, this.effects = Effects.auto});

  final OThemeMode mode;

  /// auto = reduced on low-end phones, full elsewhere.
  final Effects effects;

  Appearance copyWith({OThemeMode? mode, Effects? effects}) =>
      Appearance(mode: mode ?? this.mode, effects: effects ?? this.effects);

  factory Appearance.fromJson(Map<String, dynamic> j) => Appearance(
    mode: OThemeMode.values.byName((j['mode'] as String?) ?? 'system'),
    effects: Effects.values.byName((j['effects'] as String?) ?? 'auto'),
  );

  Map<String, dynamic> toJson() => {'mode': mode.name, 'effects': effects.name};
}
