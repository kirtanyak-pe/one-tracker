import 'package:auto_split/model/appearance.dart';
import 'package:auto_split/ui/perf.dart';
import 'package:auto_split/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effects setting round-trips; old saves default to auto', () {
    const a = Appearance(effects: Effects.reduced);
    expect(Appearance.fromJson(a.toJson()).effects, Effects.reduced);
    expect(Appearance.fromJson({'mode': 'dark'}).effects, Effects.auto);
  });

  test('lite mode drops blurred shadows', () {
    Perf.lite = false;
    expect(Shadows.card(Brightness.light), isNotEmpty);
    expect(Shadows.glow(Colors.orange), isNotEmpty);
    expect(Shadows.lifted(Colors.orange), isNotEmpty);
    expect(Shadows.floating, isNotEmpty);
    Perf.lite = true;
    expect(Shadows.card(Brightness.light), isEmpty);
    expect(Shadows.glow(Colors.orange), isEmpty);
    expect(Shadows.lifted(Colors.orange), isEmpty);
    expect(Shadows.floating, isEmpty);
    Perf.lite = false;
  });
}
