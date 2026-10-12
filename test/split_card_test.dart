import 'package:auto_split/split/split_card.dart';
import 'package:auto_split/split/split_models.dart';
import 'package:auto_split/splitwise/models.dart';
import 'package:auto_split/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _you = SwUser(id: 1, firstName: 'You');
const _aarav = SwUser(id: 2, firstName: 'Aarav', lastName: 'Mehta');
const _kabir = SwUser(id: 4, firstName: 'Kabir', lastName: 'Singh');
const _flat = SwGroup(id: 101, name: 'Flatmates', members: [_you, _aarav, _kabir]);

Future<void> _pump(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = const Size(375 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: card)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final prompt = SplitPrompt(txnId: 't', amountMinor: 45000, payee: 'Swiggy', at: DateTime(2026, 10, 13));

  testWidgets('with a default it is one tap', (tester) async {
    SplitTarget? sent;
    await _pump(
      tester,
      SplitCard(
        prompt: prompt,
        groups: const [_flat],
        friends: const [_aarav, _kabir],
        defaultTarget: SplitTarget.group(_flat),
        onSplit: (t, _) async => sent = t,
        onDismiss: () {},
      ),
    );
    expect(find.text('Flatmates'), findsOneWidget);
    expect(find.text('₹150 each, 3 people'), findsOneWidget);
    await tester.tap(find.text('Split'));
    await tester.pump();
    expect(sent!.groupId, 101);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('picking friends does not shift the chips', (tester) async {
    await _pump(
      tester,
      SplitCard(
        prompt: prompt,
        groups: const [_flat],
        friends: const [_aarav, _kabir],
        defaultTarget: SplitTarget.group(_flat),
        onSplit: (_, _) async {},
        onDismiss: () {},
      ),
    );
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Kabir Singh'));
    await tester.tap(find.text('Aarav Mehta'));
    await tester.pumpAndSettle();
    expect(find.text('Make this my default'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Kabir Singh')), before);
  });

  testWidgets('no default: picker is open and Split waits for a choice', (tester) async {
    var makeDefault = false;
    await _pump(
      tester,
      SplitCard(
        prompt: prompt,
        groups: const [_flat],
        friends: const [_aarav],
        defaultTarget: null,
        onSplit: (_, d) async => makeDefault = d,
        onDismiss: () {},
      ),
    );
    final split = find.widgetWithText(FilledButton, 'Split');
    expect(tester.widget<FilledButton>(split).onPressed, isNull);
    await tester.tap(find.text('Flatmates'));
    await tester.pumpAndSettle();
    await tester.tap(split);
    await tester.pump();
    expect(makeDefault, isTrue, reason: 'first choice becomes the default');
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('many groups: buttons stay visible, picker scrolls', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final groups = [
      for (var i = 0; i < 30; i++) SwGroup(id: 200 + i, name: 'Group number $i', members: const [_you, _aarav]),
    ];
    final friends = [for (var i = 0; i < 30; i++) SwUser(id: 500 + i, firstName: 'Friend$i')];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SplitCard(
              prompt: prompt,
              groups: groups,
              friends: friends,
              defaultTarget: null,
              onSplit: (_, _) async {},
              onDismiss: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final split = tester.getRect(find.widgetWithText(FilledButton, 'Split'));
    expect(split.bottom, lessThanOrEqualTo(640));
    expect(split.top, greaterThan(0));
  });
}
