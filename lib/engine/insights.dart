import '../model/automation.dart';
import '../model/category.dart';
import 'enrich.dart';
import 'summary.dart';

class CategoryChange {
  const CategoryChange(this.category, this.thisMonth, this.lastMonth);

  final Category category;
  final int thisMonth;
  final int lastMonth;

  int get delta => thisMonth - lastMonth;
}

class PayeeTotal {
  const PayeeTotal(this.payee, this.amountMinor, this.count);

  final String payee;
  final int amountMinor;
  final int count;
}

/// Everything the Insights tab shows for one month.
class Insights {
  const Insights({
    required this.month,
    required this.daily,
    required this.trend,
    required this.lastMonthToDate,
    required this.projectedMinor,
    required this.changes,
    required this.topPayees,
    required this.biggest,
    required this.dayOfMonth,
  });

  final MonthSummary month;

  /// Spend per day of the month, index 0 = 1st.
  final List<int> daily;

  /// Last six months' spend, oldest first (includes [month]).
  final List<MonthSummary> trend;

  /// Last month's spend up to the same day — a fair comparison mid-month.
  final int lastMonthToDate;

  /// Straight-line month-end estimate; null for past months or too early.
  final int? projectedMinor;

  /// Biggest movers vs last month, largest absolute change first.
  final List<CategoryChange> changes;
  final List<PayeeTotal> topPayees;
  final List<Enriched> biggest;

  /// Days elapsed in [month] (all of them for past months).
  final int dayOfMonth;

  int get averagePerDay => dayOfMonth == 0 ? 0 : month.spentMinor ~/ dayOfMonth;
}

Insights buildInsights(Ledger ledger, DateTime monthStart, {DateTime? now}) {
  now ??= DateTime.now();
  final month = summarize(ledger, monthStart);
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  final isCurrent = now.year == monthStart.year && now.month == monthStart.month;
  final dayOfMonth = isCurrent ? now.day : daysInMonth;

  final daily = List.filled(daysInMonth, 0);
  for (final e in month.items.where((e) => e.countsAsSpend)) {
    daily[e.txn.at.day - 1] += e.txn.amountMinor;
  }

  final trend = [
    for (var i = 5; i >= 0; i--) summarize(ledger, DateTime(monthStart.year, monthStart.month - i)),
  ];
  final previous = trend[4];

  final lastMonthToDate = previous.items
      .where((e) => e.countsAsSpend && e.txn.at.day <= dayOfMonth)
      .fold(0, (sum, e) => sum + e.txn.amountMinor);

  int? projected;
  if (isCurrent && dayOfMonth >= 5 && dayOfMonth < daysInMonth) {
    projected = (month.spentMinor / dayOfMonth * daysInMonth).round();
  }

  final thisByCat = {for (final c in month.byCategory) c.category: c.amountMinor};
  final lastByCat = {for (final c in previous.byCategory) c.category: c.amountMinor};
  final changes = [
    for (final c in {...thisByCat.keys, ...lastByCat.keys})
      CategoryChange(c, thisByCat[c] ?? 0, lastByCat[c] ?? 0),
  ].where((c) => c.delta != 0).toList()
    ..sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));

  final payees = <String, (int, int)>{};
  for (final e in month.items.where((e) => e.countsAsSpend)) {
    final (sum, n) = payees[e.payee] ?? (0, 0);
    payees[e.payee] = (sum + e.txn.amountMinor, n + 1);
  }
  final topPayees = [
    for (final MapEntry(:key, :value) in payees.entries) PayeeTotal(key, value.$1, value.$2),
  ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

  final biggest = month.items.where((e) => e.countsAsSpend).toList()
    ..sort((a, b) => b.txn.amountMinor.compareTo(a.txn.amountMinor));

  return Insights(
    month: month,
    daily: daily,
    trend: trend,
    lastMonthToDate: lastMonthToDate,
    projectedMinor: projected,
    changes: changes.take(4).toList(),
    topPayees: topPayees.take(5).toList(),
    biggest: biggest.take(3).toList(),
    dayOfMonth: dayOfMonth,
  );
}

/// A budget threshold that was just crossed.
class BudgetAlert {
  const BudgetAlert({required this.key, required this.title, required this.body});

  /// "2026-10:monthly:80" — sent once per month per threshold.
  final String key;
  final String title;
  final String body;
}

/// Thresholds crossed this month that haven't been announced yet.
List<BudgetAlert> budgetAlerts(
  MonthSummary month,
  Budgets budgets,
  Set<String> alreadySent, {
  required String Function(int minor) money,
}) {
  final period = '${month.month.year}-${month.month.month.toString().padLeft(2, '0')}';
  final alerts = <BudgetAlert>[];

  void check(String id, String name, int spent, int? limit) {
    if (limit == null || limit <= 0) return;
    for (final pct in const [100, 80]) {
      if (spent * 100 < limit * pct) continue;
      final key = '$period:$id:$pct';
      if (!alreadySent.contains(key)) {
        alerts.add(BudgetAlert(
          key: key,
          title: pct == 100 ? '$name budget used up' : '$name budget at $pct%',
          body: '${money(spent)} of ${money(limit)} spent this month',
        ));
      }
      break; // only the highest threshold reached
    }
  }

  check('monthly', 'Monthly', month.spentMinor, budgets.monthlyMinor);
  for (final c in month.byCategory) {
    check(c.category.name, c.category.label, c.amountMinor, budgets.byCategory[c.category]);
  }
  return alerts;
}
