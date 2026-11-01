import 'package:auto_split/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oct = DateTime(2026, 10), nov = DateTime(2026, 11), aug = DateTime(2026, 8);

  test('a screen on the current month follows it into the next', () {
    expect(followMonth(viewed: oct, lastCurrent: oct, current: nov), nov);
  });

  test('a past month the user picked stays put', () {
    expect(followMonth(viewed: aug, lastCurrent: oct, current: nov), aug);
  });

  test('year rollover', () {
    expect(followMonth(viewed: DateTime(2026, 12), lastCurrent: DateTime(2026, 12), current: DateTime(2027, 1)),
        DateTime(2027, 1));
    expect(currentMonthOf(DateTime(2026, 11, 1, 0, 0, 1)), nov);
  });
}
