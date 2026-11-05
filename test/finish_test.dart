import 'package:auto_split/model/appearance.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/onyx.dart';

void main() {
  for (final mode in [OThemeMode.light, OThemeMode.dark]) {
    for (final f in OFinish.values) {
      testWidgets('${f.name} (${mode.name}) draws buttons, chips and the tab bar, and presses in', (tester) async {
        await tester.pumpWidget(
          OApp(
            title: 't',
            mode: mode,
            finish: f,
            home: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OButton(label: 'Go', onPressed: () {}),
                OButton.secondary(label: 'Later', onPressed: () {}),
                OChip(label: 'Food', selected: true, onTap: () {}),
                OTabBar(
                  tabs: const [(icon: LucideIcons.house, label: 'Home'), (icon: LucideIcons.split, label: 'Split')],
                  index: 0,
                  onSelect: (_) {},
                ),
              ],
            ),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.text('Go')));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('the finish is saved with the appearance, Raised by default', () {
    expect(const Appearance().finish, OFinish.raised);
    expect(Appearance.fromJson(const {}).finish, OFinish.raised);
    final glass = const Appearance().copyWith(finish: OFinish.glass);
    expect(Appearance.fromJson(glass.toJson()).finish, OFinish.glass);
    expect(Appearance.fromJson(const {'finish': 'gone'}).finish, OFinish.raised);
  });
}
