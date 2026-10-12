import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/widget_data.dart';
import 'package:auto_split/model/automation.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
RawMessage _sms(DateTime at, String body) =>
    RawMessage(source: Source.sms, sourceId: '${_n++}', sender: 'VM-HDFCBK', body: body, at: at);

void main() {
  // Wednesday 14 Oct 2026, evening.
  final now = DateTime(2026, 10, 14, 20);
  final ledger = enrich(ingest(const [], [
    _sms(DateTime(2026, 10, 14, 9), 'Rs.450 debited from A/c XX4821 to VPA swiggy@icici'),
    _sms(DateTime(2026, 10, 14, 13), 'Rs.120 debited from A/c XX4821 to VPA uber@ybl'),
    _sms(DateTime(2026, 10, 12, 10), 'Rs.1000 debited from A/c XX4821 to VPA swiggy@icici'), // Mon
    _sms(DateTime(2026, 10, 11, 10), 'Rs.5000 debited from A/c XX4821 to VPA amazon@apl'), // Sun, last week
    _sms(DateTime(2026, 9, 30, 10), 'Rs.9999 debited from A/c XX4821 to VPA amazon@apl'), // last month
    _sms(DateTime(2026, 10, 13, 10), 'Rs.20000 credited to A/c XX4821 from VPA aarav@okaxis'), // income
  ]).txns);

  test('today, week (from Monday) and month', () {
    final p = widgetPeriods(ledger, const Budgets(), now: now);
    expect(p['today']!.amountMinor, 57000);
    // Yesterday (Tue) had nothing by this time, so no comparison: top category.
    expect(p['today']!.caption, '2 payments · mostly food & drinks');
    expect(p['week']!.amountMinor, 157000);
    expect(p['month']!.amountMinor, 657000);
    expect(p['month']!.meter, isNull);
  });

  test('periods expire at their end', () {
    final p = widgetPeriods(ledger, const Budgets(), now: now);
    expect(p['today']!.validUntil, DateTime(2026, 10, 15));
    expect(p['week']!.validUntil, DateTime(2026, 10, 19));
    expect(p['month']!.validUntil, DateTime(2026, 11));
  });

  test('month shows the budget when one is set', () {
    final p = widgetPeriods(ledger, const Budgets(monthlyMinor: 1000000), now: now);
    expect(p['month']!.meter, closeTo(0.657, 0.001));
    expect(p['month']!.caption, '₹3,430 left of ₹10k');
    expect(p['month']!.toJson()['amount'], '₹6,570');
  });

  test('empty day', () {
    final p = widgetPeriods(ledger, const Budgets(), now: DateTime(2026, 10, 15, 8));
    expect(p['today']!.amountMinor, 0);
    expect(p['today']!.caption, 'Nothing spent yet');
  });

  test('compares with the same stretch of the previous period', () {
    final l = enrich(ingest(const [], [
      _sms(DateTime(2026, 10, 13, 9), 'Rs.1000 debited from A/c XX4821 to VPA swiggy@icici'),
      _sms(DateTime(2026, 10, 13, 22), 'Rs.5000 debited from A/c XX4821 to VPA amazon@apl'), // after "now" o'clock
      _sms(DateTime(2026, 10, 14, 9), 'Rs.1500 debited from A/c XX4821 to VPA swiggy@icici'),
    ]).txns);
    final p = widgetPeriods(l, const Budgets(), now: DateTime(2026, 10, 14, 20));
    // Today ₹1,500 vs yesterday up to 8 pm ₹1,000 (the 10 pm ₹5,000 doesn't count yet).
    expect(p['today']!.caption, '1 payment · ↑50% vs yesterday');
  });

  test('last payment for the widget', () {
    expect(lastPayment(ledger)!.text, '₹120 at Uber');
  });
}
