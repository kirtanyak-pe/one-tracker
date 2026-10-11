import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/insights.dart';
import 'package:auto_split/engine/recurring.dart';
import 'package:auto_split/engine/summary.dart';
import 'package:auto_split/model/automation.dart';
import 'package:auto_split/model/category.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/money.dart';
import 'package:auto_split/sources/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
RawMessage _sms(DateTime at, String body) =>
    RawMessage(source: Source.sms, sourceId: '${_n++}', sender: 'VM-HDFCBK', body: body, at: at);

Ledger _ledger(List<RawMessage> messages, {List<AutoRule> autoRules = const []}) =>
    enrich(ingest(const [], messages).txns, autoRules: autoRules);

void main() {
  group('recurring', () {
    final now = DateTime(2026, 10, 20);

    test('monthly subscription with steady amount', () {
      final ledger = _ledger([
        for (final m in [7, 8, 9, 10])
          _sms(DateTime(2026, m, 4, 8), 'Rs.649 debited from A/c XX4821 to VPA netflix.upi@icici'),
      ]);
      final found = findRecurring(ledger, now: now);
      expect(found, hasLength(1));
      expect(found.single.payee, 'Netflix');
      expect(found.single.cadence, Cadence.monthly);
      expect(found.single.nextDue.month, 11);
    });

    test('irregular amounts are not a subscription', () {
      final ledger = _ledger([
        _sms(DateTime(2026, 8, 3), 'Rs.320 debited from A/c XX4821 to VPA blinkit@ybl'),
        _sms(DateTime(2026, 9, 3), 'Rs.2400 debited from A/c XX4821 to VPA blinkit@ybl'),
        _sms(DateTime(2026, 10, 3), 'Rs.900 debited from A/c XX4821 to VPA blinkit@ybl'),
      ]);
      expect(findRecurring(ledger, now: now), isEmpty);
    });

    test('two payments are not enough', () {
      final ledger = _ledger([
        _sms(DateTime(2026, 9, 4), 'Rs.649 debited from A/c XX4821 to VPA netflix.upi@icici'),
        _sms(DateTime(2026, 10, 4), 'Rs.649 debited from A/c XX4821 to VPA netflix.upi@icici'),
      ]);
      expect(findRecurring(ledger, now: now), isEmpty);
    });

    test('a cancelled subscription drops off', () {
      final ledger = _ledger([
        for (final m in [3, 4, 5])
          _sms(DateTime(2026, m, 4), 'Rs.119 debited from A/c XX4821 to VPA spotify@ybl'),
      ]);
      expect(findRecurring(ledger, now: now), isEmpty);
    });

    test('weekly', () {
      final ledger = _ledger([
        for (var d = 0; d < 4; d++)
          _sms(DateTime(2026, 10, 1 + d * 7), 'Rs.400 debited from A/c XX4821 to VPA maid.services@ybl'),
      ]);
      expect(findRecurring(ledger, now: now).single.cadence, Cadence.weekly);
    });
  });

  test('sample data has rent, Netflix and gym as repeats', () {
    final now = DateTime(2026, 10, 11, 22);
    final ledger = enrich(ingest(const [], sampleMessages(now)).txns);
    final payees = findRecurring(ledger, now: now).map((r) => r.payee).toSet();
    expect(payees, containsAll(['Ramesh Kumar', 'Netflix', 'Cultfit']));
    final trend = buildInsights(ledger, DateTime(2026, 10), now: now).trend;
    expect(trend.where((m) => m.spentMinor > 0), hasLength(6));
  });

  group('keyword rules', () {
    test('category, tag and kind from a keyword', () {
      final ledger = _ledger([
        _sms(DateTime(2026, 10, 1), 'Rs.500 debited from A/c XX4821 to VPA acme.canteen@ybl'),
        _sms(DateTime(2026, 10, 2), 'Rs.10000 debited from A/c XX4821 to VPA zerodha.broking@hdfc'),
      ], autoRules: const [
        AutoRule(id: 'a', contains: 'canteen', category: Category.food, tag: 'Office'),
        AutoRule(id: 'b', contains: 'ZERODHA', kind: TxnKind.notExpense),
      ]);
      final canteen = ledger.items.firstWhere((e) => e.payee.contains('Canteen'));
      expect(canteen.category, Category.food);
      expect(canteen.tags, contains('Office'));
      final broker = ledger.items.firstWhere((e) => e.payee.contains('Zerodha'));
      expect(broker.kind, TxnKind.notExpense);
      expect(broker.needsReview, isFalse);
    });

    test('a per-payment choice beats a keyword rule', () {
      final txns = ingest(const [], [
        _sms(DateTime(2026, 10, 1), 'Rs.500 debited from A/c XX4821 to VPA acme.canteen@ybl'),
      ]).txns;
      final ledger = enrich(
        [txns.single.copyWith(categoryOverride: Category.health)],
        autoRules: const [AutoRule(id: 'a', contains: 'canteen', category: Category.food)],
      );
      expect(ledger.items.single.category, Category.health);
    });
  });

  group('insights', () {
    final ledger = _ledger([
      _sms(DateTime(2026, 9, 3), 'Rs.1000 debited from A/c XX4821 to VPA swiggy@icici'),
      _sms(DateTime(2026, 9, 25), 'Rs.4000 debited from A/c XX4821 to VPA amazon@apl'),
      _sms(DateTime(2026, 10, 2), 'Rs.600 debited from A/c XX4821 to VPA swiggy@icici'),
      _sms(DateTime(2026, 10, 9), 'Rs.900 debited from A/c XX4821 to VPA swiggy@icici'),
      _sms(DateTime(2026, 10, 9, 20), 'Rs.300 debited from A/c XX4821 to VPA uber@ybl'),
    ]);
    final i = buildInsights(ledger, DateTime(2026, 10), now: DateTime(2026, 10, 10));

    test('daily totals', () {
      expect(i.daily, hasLength(31));
      expect(i.daily[1], 60000);
      expect(i.daily[8], 120000);
    });

    test('compares with last month up to the same day', () {
      expect(i.month.spentMinor, 180000);
      expect(i.lastMonthToDate, 100000); // the 25 Sep payment isn't counted yet
    });

    test('projects month end from the pace so far', () {
      expect(i.projectedMinor, (180000 / 10 * 31).round());
      final past = buildInsights(ledger, DateTime(2026, 9), now: DateTime(2026, 10, 10));
      expect(past.projectedMinor, isNull);
      expect(past.dayOfMonth, 30);
    });

    test('category movers and top payees', () {
      expect(i.changes.first.category, Category.shopping);
      expect(i.changes.first.delta, -400000);
      expect(i.topPayees.first.payee, 'Swiggy');
      expect(i.topPayees.first.count, 2);
      expect(i.biggest.first.txn.amountMinor, 90000);
      expect(i.trend, hasLength(6));
      expect(i.trend.last.month, DateTime(2026, 10));
    });
  });

  test('compact and rounded money', () {
    expect(formatCompact(85000), '₹850');
    expect(formatCompact(120000), '₹1.2k');
    expect(formatCompact(4500000), '₹45k');
    expect(formatCompact(13000000), '₹1.3L');
    expect(formatMoney(13417435, 'INR', round: true), '₹1,34,174');
    expect(formatMoney(13417435, 'INR'), '₹1,34,174.35');
  });

  group('budget alerts', () {
    MonthSummary month(int rupees, {Category category = Category.food}) => summarize(
          _ledger([_sms(DateTime(2026, 10, 5), 'Rs.$rupees debited from A/c XX4821 to VPA swiggy@icici')]),
          DateTime(2026, 10),
        );
    String money(int m) => formatMoney(m, 'INR');

    test('80% then 100%, each once', () {
      const budgets = Budgets(monthlyMinor: 1000000);
      expect(budgetAlerts(month(7000), budgets, {}, money: money), isEmpty);

      final at80 = budgetAlerts(month(8500), budgets, {}, money: money);
      expect(at80.single.key, '2026-10:monthly:80');
      expect(budgetAlerts(month(8500), budgets, {at80.single.key}, money: money), isEmpty);

      final at100 = budgetAlerts(month(10000), budgets, {at80.single.key}, money: money);
      expect(at100.single.title, 'Monthly budget used up');
    });

    test('category budgets', () {
      final alerts = budgetAlerts(
        month(3000),
        const Budgets(byCategory: {Category.food: 300000}),
        {},
        money: money,
      );
      expect(alerts.single.title, 'Food & drinks budget used up');
      expect(alerts.single.body, '₹3,000 of ₹3,000 spent this month');
    });

    test('budgets survive a save', () {
      const b = Budgets(monthlyMinor: 5000000, byCategory: {Category.food: 800000});
      final back = Budgets.fromJson(b.toJson());
      expect(back.monthlyMinor, 5000000);
      expect(back.byCategory[Category.food], 800000);
    });
  });
}
