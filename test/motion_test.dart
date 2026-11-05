import 'package:auto_split/ui/motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/onyx.dart';

Widget _app(Widget child, {bool reduce = false}) => OApp(
  title: 'test',
  mode: OThemeMode.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: child,
  ),
);

void main() {
  testWidgets('money counts up to the final value', (tester) async {
    await tester.pumpWidget(_app(const AnimatedMoney(0)));
    await tester.pumpWidget(_app(const AnimatedMoney(1234500)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('₹12,345'), findsNothing); // still counting
    await tester.pumpAndSettle();
    expect(find.text('₹12,345'), findsOneWidget);
  });

  testWidgets('reduced motion jumps straight to the end', (tester) async {
    await tester.pumpWidget(_app(const AnimatedMoney(0), reduce: true));
    await tester.pumpWidget(_app(const AnimatedMoney(1234500), reduce: true));
    await tester.pump();
    expect(find.text('₹12,345'), findsOneWidget);
  });

  testWidgets('entrance ends fully visible', (tester) async {
    await tester.pumpWidget(_app(const FadeSlideIn(index: 3, child: Text('hi'))));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('entrance is instant with reduced motion', (tester) async {
    await tester.pumpWidget(_app(const FadeSlideIn(index: 3, child: Text('hi')), reduce: true));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
