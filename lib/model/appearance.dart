import 'package:onyx/onyx.dart';

/// Theme choices. Default: follow the system for light/dark.
/// Animations and soft effects.
enum Effects { auto, reduced, full }

class Appearance {
  const Appearance({
    this.mode = OThemeMode.system,
    this.effects = Effects.auto,
    this.lock = true,
    this.finish = OFinish.raised,
  });

  final OThemeMode mode;

  /// auto = reduced on low-end phones, full elsewhere.
  final Effects effects;

  /// App lock: opening the app asks for the phone's fingerprint or screen
  /// lock. On by default where the phone has a screen lock.
  final bool lock;

  /// How buttons, chips and the tab bar look (Raised, Glass, …).
  final OFinish finish;

  Appearance copyWith({OThemeMode? mode, Effects? effects, bool? lock, OFinish? finish}) => Appearance(
    mode: mode ?? this.mode,
    effects: effects ?? this.effects,
    lock: lock ?? this.lock,
    finish: finish ?? this.finish,
  );

  factory Appearance.fromJson(Map<String, dynamic> j) => Appearance(
    mode: OThemeMode.values.byName((j['mode'] as String?) ?? 'system'),
    effects: Effects.values.byName((j['effects'] as String?) ?? 'auto'),
    lock: (j['lock'] as bool?) ?? true,
    finish: OFinish.values.asNameMap()[j['finish']] ?? OFinish.raised,
  );

  Map<String, dynamic> toJson() => {'mode': mode.name, 'effects': effects.name, 'lock': lock, 'finish': finish.name};
}
