import 'package:auto_split/model/appearance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/onyx.dart';

void main() {
  test('effects setting round-trips; old saves default to auto', () {
    const a = Appearance(effects: Effects.reduced);
    expect(Appearance.fromJson(a.toJson()).effects, Effects.reduced);
    expect(Appearance.fromJson({'mode': 'dark'}).effects, Effects.auto);
    expect(Appearance.fromJson({'mode': 'dark'}).mode, OThemeMode.dark);
  });
}
