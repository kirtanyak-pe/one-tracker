import '../model/category.dart';
import '../model/transaction.dart';
import 'classify.dart';
import 'enrich.dart';

enum Cadence {
  weekly('Weekly', Duration(days: 7)),
  monthly('Monthly', Duration(days: 30));

  const Cadence(this.label, this.period);

  final String label;
  final Duration period;
}

/// A payment that keeps coming back — subscription, rent, SIP, recharge.
class Recurring {
  const Recurring({
    required this.payee,
    required this.key,
    required this.category,
    required this.cadence,
    required this.amountMinor,
    required this.lastPaid,
    required this.count,
  });

  final String payee;
  final String key;
  final Category category;
  final Cadence cadence;

  /// The latest amount paid.
  final int amountMinor;
  final DateTime lastPaid;
  final int count;

  DateTime get nextDue => lastPaid.add(cadence.period);

  /// Monthly cost, for totals (weekly × ~4.3).
  int get monthlyMinor => cadence == Cadence.weekly ? (amountMinor * 30 / 7).round() : amountMinor;
}

/// Finds payees paid on a steady rhythm with steady amounts. Needs at least
/// three payments (two gaps) so a one-off repeat isn't called a subscription.
List<Recurring> findRecurring(Ledger ledger, {DateTime? now}) {
  now ??= DateTime.now();
  final byPayee = <String, List<Enriched>>{};
  for (final e in ledger.items) {
    if (e.txn.direction != Direction.debit || e.kind != TxnKind.expense) continue;
    final key = payeeKey(e.txn);
    if (key.isEmpty) continue;
    byPayee.putIfAbsent(key, () => []).add(e);
  }

  final found = <Recurring>[];
  for (final MapEntry(:key, value: payments) in byPayee.entries) {
    if (payments.length < 3) continue;
    payments.sort((a, b) => a.txn.at.compareTo(b.txn.at));

    final gaps = [
      for (var i = 1; i < payments.length; i++)
        payments[i].txn.at.difference(payments[i - 1].txn.at).inHours / 24,
    ];
    final cadence = _cadence(gaps);
    if (cadence == null) continue;

    final amounts = payments.map((e) => e.txn.amountMinor).toList()..sort();
    final median = amounts[amounts.length ~/ 2];
    // Same-ish amount every time (±20%) — a grocery store you visit monthly isn't a bill.
    if (amounts.any((a) => (a - median).abs() > median * 0.2)) continue;

    final last = payments.last;
    // Stopped? Skip if it's more than 1.5 periods overdue.
    if (now.difference(last.txn.at) > cadence.period * 1.5) continue;

    found.add(Recurring(
      payee: last.payee,
      key: key,
      category: last.category,
      cadence: cadence,
      amountMinor: last.txn.amountMinor,
      lastPaid: last.txn.at,
      count: payments.length,
    ));
  }
  found.sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return found;
}

Cadence? _cadence(List<double> gaps) {
  bool all(double lo, double hi) => gaps.every((g) => g >= lo && g <= hi);
  if (all(25, 35)) return Cadence.monthly;
  if (all(6, 8)) return Cadence.weekly;
  return null;
}
