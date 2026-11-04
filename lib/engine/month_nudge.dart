import 'enrich.dart';

/// "3 payments on 28–31 Oct. Count them in November?" — payments from the
/// last days of last month that still count there, offered in the first days
/// of the new one (salary lands late, bills are paid the same day).
class MonthNudge {
  const MonthNudge({required this.paidMonth, required this.firstDay, required this.lastDay, required this.items});

  /// First day of the month they were paid in.
  final DateTime paidMonth;

  /// The window, e.g. 28 and 31.
  final int firstDay;
  final int lastDay;

  /// Newest first.
  final List<Enriched> items;

  /// First day of the month they could count in.
  DateTime get nextMonth => DateTime(paidMonth.year, paidMonth.month + 1);

  /// "2026-10": remembers a "Not now".
  String get key => nudgeKey(paidMonth);
}

String nudgeKey(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// Days at the end of a month that make up the window.
const nudgeWindowDays = 4;

/// Days at the start of a month the card is shown for.
const nudgeShowDays = 5;

/// The nudge to show on [now], or null: only in the first days of a month,
/// only for expense payments from the last days of the previous one that
/// haven't been moved, and not after "Not now".
MonthNudge? buildMonthNudge(Ledger ledger, Set<String> dismissed, {DateTime? now}) {
  now ??= DateTime.now();
  if (now.day > nudgeShowDays) return null;
  final paidMonth = DateTime(now.year, now.month - 1);
  if (dismissed.contains(nudgeKey(paidMonth))) return null;
  final lastDay = DateTime(now.year, now.month, 0).day;
  final firstDay = lastDay - nudgeWindowDays + 1;
  final items = ledger.items
      .where((e) =>
          e.countsAsSpend &&
          e.txn.countMonth == null &&
          e.txn.at.year == paidMonth.year &&
          e.txn.at.month == paidMonth.month &&
          e.txn.at.day >= firstDay)
      .toList();
  if (items.isEmpty) return null;
  return MonthNudge(paidMonth: paidMonth, firstDay: firstDay, lastDay: lastDay, items: items);
}
