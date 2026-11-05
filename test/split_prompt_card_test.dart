import 'package:auto_split/screens/widgets/split_prompt_card.dart';
import 'package:onyx/onyx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Brightness brightness, SplitPromptCard card, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(375 * 3, 812 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    OApp(
      title: 'test',
      mode: brightness == Brightness.dark ? OThemeMode.dark : OThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(375, 812), textScaler: TextScaler.linear(textScale)),
        child: Padding(padding: const EdgeInsets.all(20), child: card),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SplitPromptCard _card({Future<void> Function()? onSplit, Future<void> Function()? onSkip, VoidCallback? onDone}) =>
    SplitPromptCard(
      txnId: 't1',
      payee: 'Swiggy',
      amountMinor: 45000,
      at: DateTime.now().subtract(const Duration(minutes: 5)),
      onSplit: onSplit,
      onSkip: onSkip,
      onDone: onDone,
    );

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shows payee, amount, one context line and two 48dp actions ($brightness, big font)', (tester) async {
      await _pump(tester, brightness, _card(onSplit: () async {}, onSkip: () async {}), textScale: 1.3);

      expect(find.text('Split at Swiggy?'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      expect(find.textContaining('Opens Splitwise with this filled in'), findsOneWidget);
      // No picker, no extra controls.
      expect(find.byType(OButton), findsNWidgets(2));

      // An ink card: ink fill, header text in onInk, primary action inverse.
      final t = OTheme.of(tester.element(find.byType(SplitPromptCard))).colors;
      final card = tester.widget<OCard>(
        find.descendant(of: find.byType(SplitPromptCard), matching: find.byType(OCard)),
      );
      expect(card.color, t.ink);
      expect(tester.widget<Text>(find.text('Split at Swiggy?')).style!.color, t.onInk);
      final primary = tester.widget<OButton>(
        find.ancestor(of: find.text('Split in Splitwise'), matching: find.byType(OButton)),
      );
      expect(primary.variant, OButtonVariant.inverse);
      for (final label in ['Skip', 'Split in Splitwise']) {
        final button = find.ancestor(of: find.text(label), matching: find.byType(OButton));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48), reason: label);
        expect(tester.getSize(find.text(label)).height, lessThan(30), reason: '$label on one line');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Split in Splitwise runs onSplit then onDone', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      Brightness.light,
      _card(
        onSplit: () async => calls.add('split'),
        onSkip: () async => calls.add('skip'),
        onDone: () => calls.add('done'),
      ),
    );
    await tester.tap(find.text('Split in Splitwise'));
    await tester.pumpAndSettle();
    expect(calls, ['split', 'done']);
  });

  testWidgets('Skip runs onSkip then onDone', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      Brightness.light,
      _card(
        onSplit: () async => calls.add('split'),
        onSkip: () async => calls.add('skip'),
        onDone: () => calls.add('done'),
      ),
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(calls, ['skip', 'done']);
  });
}
