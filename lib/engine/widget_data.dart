import '../model/automation.dart';
import '../model/category.dart';
import '../money.dart';
import 'enrich.dart';

/// What the home-screen widget shows for one period.
class WidgetPeriod {
  const WidgetPeriod({
    required this.title,
    required this.amountMinor,
    required this.caption,
    required this.validUntil,
    this.meter,
  });

  final String title;
  final int amountMinor;
  final String caption;

  /// End of the period; after this the numbers are stale until the app runs.
  final DateTime validUntil;

  /// 0..1+ budget use (month only, when a budget is set).
  final double? meter;

  Map<String, Object?> toJson() => {
        'title': title,
        'amount': formatMoney(amountMinor, appCurrency, round: true),
        'caption': caption,
        'validUntil': validUntil.millisecondsSinceEpoch,
        'meter': meter,
      };
}

DateTime _startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Today / this week (Mon–Sun) / this month, ready for the widget.
Map<String, WidgetPeriod> widgetPeriods(Ledger ledger, Budgets budgets, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final week = _startOfWeek(now);
  final month = DateTime(now.year, now.month);

  ({int spent, int count, Category? top}) range(DateTime start, DateTime end) {
    var spent = 0, count = 0;
    final byCat = <Category, int>{};
    for (final e in ledger.items) {
      if (!e.countsAsSpend || e.countAt.isBefore(start) || !e.countAt.isBefore(end)) continue;
      spent += e.txn.amountMinor;
      count++;
      byCat[e.category] = (byCat[e.category] ?? 0) + e.txn.amountMinor;
    }
    final top = byCat.entries.fold<MapEntry<Category, int>?>(
      null,
      (best, e) => best == null || e.value > best.value ? e : best,
    );
    return (spent: spent, count: count, top: top?.key);
  }

  // Same stretch of the previous period, up to the same point in time.
  String? versus(DateTime start, DateTime prevStart, int spent, String label) {
    final prev = range(prevStart, prevStart.add(now!.difference(start))).spent;
    if (prev < 10000 || spent == 0) return null; // too little to compare
    final pct = ((spent - prev) / prev * 100).round();
    if (pct.abs() < 5) return 'same as $label';
    return '${pct > 0 ? '↑' : '↓'}${pct.abs() > 300 ? '300+' : pct.abs()}% vs $label';
  }

  String caption(int count, Category? top, String? vs) {
    if (count == 0) return 'Nothing spent yet';
    final payments = '$count payment${count == 1 ? '' : 's'}';
    // The comparison is more useful than the top category when there is one.
    if (vs != null) return '$payments · $vs';
    return top == null ? payments : '$payments · mostly ${top.label.toLowerCase()}';
  }

  final t = range(today, today.add(const Duration(days: 1)));
  final w = range(week, week.add(const Duration(days: 7)));
  final monthEnd = DateTime(now.year, now.month + 1);
  final m = range(month, monthEnd);
  final tVs = versus(today, today.subtract(const Duration(days: 1)), t.spent, 'yesterday');
  final wVs = versus(week, week.subtract(const Duration(days: 7)), w.spent, 'last week');
  final mVs = versus(month, DateTime(now.year, now.month - 1), m.spent, 'last month');

  final limit = budgets.monthlyMinor;
  final String monthCaption;
  double? meter;
  if (limit != null && limit > 0) {
    meter = m.spent / limit;
    monthCaption = m.spent > limit
        ? '${formatMoney(m.spent - limit, appCurrency, round: true)} over your ${formatCompact(limit)} budget'
        : '${formatMoney(limit - m.spent, appCurrency, round: true)} left of ${formatCompact(limit)}';
  } else {
    monthCaption = caption(m.count, m.top, mVs);
  }

  return {
    'today': WidgetPeriod(
      title: 'Spent today',
      amountMinor: t.spent,
      caption: caption(t.count, t.top, tVs),
      validUntil: today.add(const Duration(days: 1)),
    ),
    'week': WidgetPeriod(
      title: 'Spent this week',
      amountMinor: w.spent,
      caption: caption(w.count, w.top, wVs),
      validUntil: week.add(const Duration(days: 7)),
    ),
    'month': WidgetPeriod(
      title: 'Spent this month',
      amountMinor: m.spent,
      caption: monthCaption,
      validUntil: monthEnd,
      meter: meter,
    ),
  };
}

/// The newest real payment, for the widget's "Last:" line.
({String text, DateTime at})? lastPayment(Ledger ledger) {
  final e = ledger.items.where((e) => e.countsAsSpend).firstOrNull;
  if (e == null) return null;
  return (text: '${formatMoney(e.txn.amountMinor, appCurrency, round: true)} at ${e.payee}', at: e.txn.at);
}
