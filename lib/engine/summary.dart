import '../model/category.dart';
import '../model/transaction.dart';
import 'enrich.dart';

class CategoryTotal {
  const CategoryTotal(this.category, this.amountMinor, this.count);

  final Category category;
  final int amountMinor;
  final int count;
}

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.spentMinor,
    required this.spendCount,
    required this.incomeMinor,
    required this.excludedMinor,
    required this.byCategory,
    required this.items,
  });

  /// First day of the month.
  final DateTime month;
  final int spentMinor;
  final int spendCount;
  final int incomeMinor;

  /// Money out that isn't spending: self transfers + "not an expense".
  final int excludedMinor;

  /// Biggest first.
  final List<CategoryTotal> byCategory;

  /// What counts in this month (including payments moved here), newest first.
  final List<Enriched> items;
}

MonthSummary summarize(Ledger ledger, DateTime month) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final items = ledger.items
      .where((e) => !e.countAt.isBefore(start) && e.countAt.isBefore(end))
      .toList();

  var spent = 0, count = 0, income = 0, excluded = 0;
  final totals = <Category, (int, int)>{};
  for (final e in items) {
    final amount = e.txn.amountMinor;
    if (e.countsAsSpend) {
      spent += amount;
      count++;
      final (sum, n) = totals[e.category] ?? (0, 0);
      totals[e.category] = (sum + amount, n + 1);
    } else if (e.kind == TxnKind.income) {
      income += amount;
    } else if (e.kind.excluded && e.txn.direction == Direction.debit) {
      // Money out only — the credit side of a self transfer isn't extra.
      excluded += amount;
    }
  }

  return MonthSummary(
    month: start,
    spentMinor: spent,
    spendCount: count,
    incomeMinor: income,
    excludedMinor: excluded,
    byCategory: [
      for (final entry in totals.entries) CategoryTotal(entry.key, entry.value.$1, entry.value.$2),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor)),
    items: items,
  );
}
