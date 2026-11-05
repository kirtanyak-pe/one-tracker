import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/screens/widgets/review_card.dart';
import 'package:onyx/onyx.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('buttons stay readable and on one line ($brightness, big font)', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final txns = ingest(const [], [
        RawMessage(
          source: Source.sms,
          sourceId: '1',
          sender: 'VM-HDFCBK',
          body: 'Rs.18000 debited from A/c XX4821 to VPA ramesh.kumar@oksbi',
          at: DateTime(2026, 10, 6),
        ),
      ]).txns;
      final queue = enrich(txns).items.where((e) => e.needsReview).toList();
      expect(queue, hasLength(1));

      await tester.pumpWidget(
        OApp(
          title: 'test',
          mode: brightness == Brightness.dark ? OThemeMode.dark : OThemeMode.light,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(375, 812), textScaler: TextScaler.linear(1.3)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ReviewCard(queue: queue, currency: 'INR'),
            ),
          ),
        ),
      );

      // One line each: label height ≈ one line of 15px text × 1.3.
      for (final label in ['Not expense', 'Expense']) {
        expect(tester.getSize(find.text(label)).height, lessThan(30), reason: label);
      }

      // An ink card; primary is the inverse (canvas-filled) action, secondary a soft one.
      final t = OTheme.of(tester.element(find.byType(ReviewCard))).colors;
      final card = tester.widget<OCard>(find.descendant(of: find.byType(ReviewCard), matching: find.byType(OCard)));
      expect(card.color, t.ink);
      OButton button(String label) =>
          tester.widget<OButton>(find.ancestor(of: find.text(label), matching: find.byType(OButton)));
      expect(button('Expense').variant, OButtonVariant.inverse);
      expect(button('Not expense').variant, OButtonVariant.inverseSoft);
      for (final label in ['Not expense', 'Expense']) {
        final b = find.ancestor(of: find.text(label), matching: find.byType(OButton));
        expect(tester.getSize(b).height, greaterThanOrEqualTo(48), reason: label);
      }
      // Payee and amount sit in the header row.
      expect(find.text('ramesh.kumar@oksbi'), findsNothing);
      expect(find.text('₹18,000'), findsOneWidget);
      expect(find.text('Count it as an expense?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
