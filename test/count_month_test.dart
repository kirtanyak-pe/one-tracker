import 'dart:convert';

import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/insights.dart';
import 'package:auto_split/engine/month_nudge.dart';
import 'package:auto_split/engine/summary.dart';
import 'package:auto_split/engine/widget_data.dart';
import 'package:auto_split/model/automation.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
RawMessage _sms(DateTime at, String body) =>
    RawMessage(source: Source.sms, sourceId: '${_n++}', sender: 'VM-HDFCBK', body: body, at: at);

Txn _debit(DateTime at, int rupees, {DateTime? countMonth}) => ingest(const [], [
      _sms(at, 'Rs.$rupees debited from A/c XX4821 to VPA shop$_n@icici'),
    ]).txns.single.copyWith(countMonth: countMonth);

Ledger _ledger(List<Txn> txns) => enrich(txns);

void main() {
  final oct = DateTime(2026, 10), nov = DateTime(2026, 11);

  group('model', () {
    test('countMonth survives JSON, null stays null', () {
      final t = _debit(DateTime(2026, 10, 28, 9), 1000);
      expect(Txn.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>).countMonth, isNull);
      final moved = t.copyWith(countMonth: t.nextMonth);
      final back = Txn.fromJson(jsonDecode(jsonEncode(moved.toJson())) as Map<String, dynamic>);
      expect(back.countMonth, nov);
      expect(back.at, t.at);
    });

    test('old stored payments without the field load fine', () {
      final json = _debit(DateTime(2026, 10, 28), 1).toJson()..remove('countMonth');
      expect(Txn.fromJson(json).countMonth, isNull);
    });

    test('copyWith keeps it, clearCountMonth drops it', () {
      final t = _debit(DateTime(2026, 10, 28), 1);
      final moved = t.copyWith(countMonth: t.nextMonth);
      expect(moved.copyWith(reviewed: true).countMonth, nov);
      expect(moved.copyWith(clearCountMonth: true).countMonth, isNull);
    });

    test('next month crosses the year boundary', () {
      expect(_debit(DateTime(2026, 12, 30, 10), 1).nextMonth, DateTime(2027, 1));
    });

    test('a re-parse keeps the move', () {
      final t = _debit(DateTime(2026, 10, 28), 500);
      expect(reparse(t.copyWith(countMonth: t.nextMonth)).countMonth, nov);
    });
  });

  group('Enriched.countAt', () {
    test('is the paid time unless moved, then the 1st of the month', () {
      final paid = DateTime(2026, 10, 28, 14, 30);
      final t = _debit(paid, 800);
      expect(_ledger([t]).items.single.countAt, paid);
      final moved = _ledger([t.copyWith(countMonth: nov)]).items.single;
      expect(moved.countAt, DateTime(2026, 11));
      expect(moved.txn.at, paid); // lists keep the real time
    });
  });

  group('summarize', () {
    test('a moved payment counts in the next month only', () {
      final a = _debit(DateTime(2026, 10, 10), 1000);
      final bill = _debit(DateTime(2026, 10, 28), 5000);
      final ledger = _ledger([a, bill.copyWith(countMonth: bill.nextMonth)]);
      final o = summarize(ledger, oct), n = summarize(ledger, nov);
      expect(o.spentMinor, 100000);
      expect(o.items, hasLength(1));
      expect(n.spentMinor, 500000);
      expect(n.items.single.txn.at, DateTime(2026, 10, 28)); // real date kept
      expect(n.byCategory.single.count, 1);
    });

    test('moving across a year boundary', () {
      final bill = _debit(DateTime(2026, 12, 29), 2500);
      final ledger = _ledger([bill.copyWith(countMonth: bill.nextMonth)]);
      expect(summarize(ledger, DateTime(2026, 12)).spentMinor, 0);
      expect(summarize(ledger, DateTime(2027, 1)).spentMinor, 250000);
    });

    test('moving back restores the paid month', () {
      final bill = _debit(DateTime(2026, 10, 28), 5000);
      final moved = bill.copyWith(countMonth: bill.nextMonth);
      final back = moved.copyWith(clearCountMonth: true);
      expect(summarize(_ledger([back]), oct).spentMinor, 500000);
      expect(summarize(_ledger([back]), nov).spentMinor, 0);
    });

    test('budget alerts follow the moved spend', () {
      final bill = _debit(DateTime(2026, 10, 28), 9000);
      final ledger = _ledger([bill.copyWith(countMonth: bill.nextMonth)]);
      String money(int m) => '$m';
      const budgets = Budgets(monthlyMinor: 1000000);
      expect(budgetAlerts(summarize(ledger, oct), budgets, {}, money: money), isEmpty);
      expect(budgetAlerts(summarize(ledger, nov), budgets, {}, money: money), hasLength(1));
    });
  });

  group('insights', () {
    test('daily bars put a moved payment on the 1st of its month', () {
      final bill = _debit(DateTime(2026, 10, 28), 5000);
      final ledger = _ledger([bill.copyWith(countMonth: bill.nextMonth)]);
      final i = buildInsights(ledger, nov, now: DateTime(2026, 11, 10));
      expect(i.daily[0], 500000);
      expect(i.daily.fold(0, (a, b) => a + b), 500000);
      expect(buildInsights(ledger, oct, now: DateTime(2026, 11, 10)).daily.fold(0, (a, b) => a + b), 0);
    });

    test('last month to date uses the counted day', () {
      final bill = _debit(DateTime(2026, 10, 28), 5000);
      final ledger = _ledger([bill.copyWith(countMonth: bill.nextMonth)]);
      // Looking at December: November's spend up to day 1 includes it.
      expect(buildInsights(ledger, DateTime(2026, 12), now: DateTime(2026, 12, 1)).lastMonthToDate, 500000);
    });
  });

  group('widget periods', () {
    test('month and today use the counted date', () {
      final bill = _debit(DateTime(2026, 10, 28, 9), 5000);
      final ledger = _ledger([bill.copyWith(countMonth: bill.nextMonth)]);
      final onTheDay = widgetPeriods(ledger, const Budgets(), now: DateTime(2026, 10, 28, 20));
      expect(onTheDay['today']!.amountMinor, 0);
      expect(onTheDay['month']!.amountMinor, 0);
      final firstOfNov = widgetPeriods(ledger, const Budgets(), now: DateTime(2026, 11, 1, 20));
      expect(firstOfNov['month']!.amountMinor, 500000);
    });
  });

  group('month nudge', () {
    final late = [
      _debit(DateTime(2026, 10, 28, 9), 5000),
      _debit(DateTime(2026, 10, 31, 9), 300),
      _debit(DateTime(2026, 10, 27, 9), 70), // before the window
      _debit(DateTime(2026, 10, 15, 9), 90),
    ];

    test('offers the last 4 days of last month in the first days of the next', () {
      final n = buildMonthNudge(_ledger(late), {}, now: DateTime(2026, 11, 2))!;
      expect(n.items, hasLength(2));
      expect((n.firstDay, n.lastDay), (28, 31));
      expect(n.nextMonth, nov);
      expect(n.key, '2026-10');
    });

    test('quiet later in the month, after "Not now", or once moved', () {
      expect(buildMonthNudge(_ledger(late), {}, now: DateTime(2026, 11, 6)), isNull);
      expect(buildMonthNudge(_ledger(late), {'2026-10'}, now: DateTime(2026, 11, 2)), isNull);
      final moved = [for (final t in late) t.copyWith(countMonth: t.nextMonth)];
      expect(buildMonthNudge(_ledger(moved), {}, now: DateTime(2026, 11, 2)), isNull);
    });

    test('skips money in and non-expenses', () {
      final income = ingest(const [], [
        _sms(DateTime(2026, 10, 29, 9), 'Rs.20000 credited to A/c XX4821 from VPA aarav@okaxis'),
      ]).txns.single;
      expect(buildMonthNudge(_ledger([income]), {}, now: DateTime(2026, 11, 1)), isNull);
    });

    test('works across the year boundary', () {
      final t = _debit(DateTime(2026, 12, 30, 9), 100);
      final n = buildMonthNudge(_ledger([t]), {}, now: DateTime(2027, 1, 3))!;
      expect(n.paidMonth, DateTime(2026, 12));
      expect(n.nextMonth, DateTime(2027, 1));
    });
  });
}
