import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/insights.dart';
import 'package:auto_split/engine/recurring.dart';
import 'package:auto_split/engine/summary.dart';
import 'package:auto_split/engine/widget_data.dart';
import 'package:auto_split/model/automation.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// A heavy user's year: ~3,000 bank SMS, mixed payees, some transfers.
List<RawMessage> heavyYear() {
  final start = DateTime(2025, 10, 13);
  final payees = ['swiggy@icici', 'zomato@hdfc', 'uber@ybl', 'blinkit@hdfcbank', 'rahul.k@okaxis',
      'meera.iyer@okaxis', 'paytmqr2810${'0' * 6}@paytm', 'netflix.upi@icici', 'amazon@apl', 'bigbasket@hdfcbank'];
  return [
    for (var i = 0; i < 3000; i++)
      RawMessage(
        source: Source.sms,
        sourceId: 'b$i',
        sender: 'VM-HDFCBK',
        body: i % 37 == 0
            ? 'Your A/c XX7712 credited by Rs.${1000 + i % 500}.00 on IMPS from A/c XX4821. Ref ${900000 + i}'
            : 'Rs.${100 + (i * 37) % 4000}.00 debited from A/c XX4821 to VPA ${payees[i % payees.length]} UPI Ref ${500000 + i}',
        at: start.add(Duration(minutes: i * 175)),
      ),
  ];
}

int ms(void Function() f) {
  final sw = Stopwatch()..start();
  f();
  return sw.elapsedMilliseconds;
}

void main() {
  test('engine timings for 3,000 transactions', () {
    late List<Txn> txns;
    late Ledger ledger;
    final now = DateTime(2026, 10, 13);
    final tIngest = ms(() => txns = ingest(const [], heavyYear()).txns);
    final tReparse = ms(() => txns.map(reparse).toList());
    final tEnrich = ms(() => ledger = enrich(txns, autoRules: const [AutoRule(id: 'a', contains: 'canteen', tag: 'x')]));
    final tMonth = ms(() => summarize(ledger, DateTime(2026, 10)));
    final tInsights = ms(() => buildInsights(ledger, DateTime(2026, 10), now: now));
    final tRecurring = ms(() => findRecurring(ledger, now: now));
    final tWidget = ms(() => widgetPeriods(ledger, const Budgets(), now: now));
    // ignore: avoid_print
    print('ingest=${tIngest}ms reparse=${tReparse}ms enrich=${tEnrich}ms month=${tMonth}ms '
        'insights=${tInsights}ms recurring=${tRecurring}ms widget=${tWidget}ms');
    expect(ledger.items, hasLength(txns.length));
  });
}
