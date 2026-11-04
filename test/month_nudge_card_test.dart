import 'package:auto_split/app_controller.dart';
import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/month_nudge.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/screens/widgets/month_nudge_card.dart';
import 'package:auto_split/storage/app_store.dart';
import 'package:auto_split/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  for (final brightness in Brightness.values) {
    testWidgets('card and sheet fit a phone with big text ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final ledger = enrich(ingest(const [], [
        for (final (i, day) in [28, 29, 31].indexed)
          RawMessage(
            source: Source.sms,
            sourceId: '$i',
            sender: 'VM-HDFCBK',
            body: 'Rs.${1000 * (i + 1)} debited from A/c XX4821 to VPA bill$i@icici',
            at: DateTime(2026, 10, day, 10),
          ),
      ]).txns);
      final nudge = buildMonthNudge(ledger, {}, now: DateTime(2026, 11, 2))!;

      await tester.pumpWidget(
        AppScope(
          controller: AppController(AppStore()),
          child: MaterialApp(
            theme: buildTheme(brightness),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(375, 812), textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: Padding(padding: const EdgeInsets.all(20), child: MonthNudgeCard(nudge: nudge)),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Count in November?'), findsOneWidget);
      expect(find.text('3 payments on 28–31 Oct'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Count in November'), findsOneWidget);
      expect(find.text('Count 3 in November'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));

      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pump();
      expect(find.text('Count 2 in November'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
