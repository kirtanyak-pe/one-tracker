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
      if (!e.countsAsSpend || e.txn.at.isBefore(start) || !e.txn.at.isBefore(end)) continue;
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

  String caption(int count, Category? top, {String empty = 'Nothing spent yet'}) {
    if (count == 0) return empty;
    final payments = '$count payment${count == 1 ? '' : 's'}';
    return top == null ? payments : '$payments · mostly ${top.label.toLowerCase()}';
  }

  final t = range(today, today.add(const Duration(days: 1)));
  final w = range(week, week.add(const Duration(days: 7)));
  final monthEnd = DateTime(now.year, now.month + 1);
  final m = range(month, monthEnd);

  final limit = budgets.monthlyMinor;
  final String monthCaption;
  double? meter;
  if (limit != null && limit > 0) {
    meter = m.spent / limit;
    monthCaption = m.spent > limit
        ? '${formatMoney(m.spent - limit, appCurrency, round: true)} over your ${formatCompact(limit)} budget'
        : '${formatMoney(limit - m.spent, appCurrency, round: true)} left of ${formatCompact(limit)}';
  } else {
    monthCaption = caption(m.count, m.top);
  }

  return {
    'today': WidgetPeriod(
      title: 'Spent today',
      amountMinor: t.spent,
      caption: caption(t.count, t.top),
      validUntil: today.add(const Duration(days: 1)),
    ),
    'week': WidgetPeriod(
      title: 'Spent this week',
      amountMinor: w.spent,
      caption: caption(w.count, w.top),
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
