import 'models.dart';

/// Payer pays the full amount; everyone (payer included) owes an equal part.
/// Leftover paise go one each to the first participants so shares always
/// add up to [totalMinor] exactly.
List<ExpenseShare> equalSplit({
  required int payerId,
  required List<int> participantIds,
  required int totalMinor,
}) {
  final ids = {payerId, ...participantIds}.toList();
  final base = totalMinor ~/ ids.length;
  final remainder = totalMinor % ids.length;
  return [
    for (var i = 0; i < ids.length; i++)
      ExpenseShare(
        userId: ids[i],
        paidMinor: ids[i] == payerId ? totalMinor : 0,
        owedMinor: base + (i < remainder ? 1 : 0),
      ),
  ];
}

/// Splitwise's ways to divide a bill.
enum SplitMode {
  equal('Equal'),
  exact('₹'),
  percent('%'),
  shares('Shares'),
  adjust('±');

  const SplitMode(this.short);

  /// Label for the mode switch.
  final String short;

  /// Works for any total, so it can be a default split.
  bool get scales => this == equal || this == percent || this == shares;
}

/// Who owes what, or why it doesn't add up yet.
class SplitResult {
  const SplitResult._(this.shares, this.error);

  final List<ExpenseShare> shares;

  /// Human-readable problem ("₹50 left to assign"); null when valid.
  final String? error;

  bool get ok => error == null;

  int owedBy(int userId) => shares.where((s) => s.userId == userId).fold<int>(0, (sum, s) => sum + s.owedMinor);
}

String _rupees(int minor) {
  final whole = minor ~/ 100, paise = (minor % 100).abs();
  return paise == 0 ? '₹$whole' : '₹$whole.${paise.toString().padLeft(2, '0')}';
}

/// Turns a split plan into exact shares that always add up to [totalMinor].
///
/// [values] depend on [mode]:
/// - exact: paise each person owes
/// - percent: basis points (4000 = 40%)
/// - shares: whole-number weights (2 : 1 : 1)
/// - adjust: paise added to (or taken from) an equal split
/// - equal: ignored
///
/// [payerId] paid the whole amount; they owe nothing unless they're in
/// [participantIds].
SplitResult computeShares({
  required int totalMinor,
  required List<int> participantIds,
  required SplitMode mode,
  required int payerId,
  Map<int, int> values = const {},
}) {
  final ids = participantIds.toSet().toList();
  if (ids.isEmpty) return const SplitResult._([], 'Pick at least one person');
  if (totalMinor <= 0) return const SplitResult._([], 'Amount must be more than ₹0');

  int v(int id) => values[id] ?? 0;
  List<int> owed;

  switch (mode) {
    case SplitMode.equal:
      owed = _largestRemainder(totalMinor, [for (final _ in ids) 1]);
    case SplitMode.exact:
      owed = [for (final id in ids) v(id)];
      if (owed.any((o) => o < 0)) return const SplitResult._([], "Amounts can't be negative");
      final left = totalMinor - owed.fold<int>(0, (a, b) => a + b);
      if (left > 0) return SplitResult._(const [], '${_rupees(left)} left to assign');
      if (left < 0) return SplitResult._(const [], '${_rupees(-left)} over the total');
    case SplitMode.percent:
      final bps = [for (final id in ids) v(id)];
      if (bps.any((b) => b < 0)) return const SplitResult._([], "Percentages can't be negative");
      final sum = bps.fold<int>(0, (a, b) => a + b);
      if (sum != 10000) {
        final pct = sum / 100;
        return SplitResult._(const [], 'Adds up to ${pct == pct.roundToDouble() ? pct.round() : pct}%, needs 100%');
      }
      owed = _largestRemainder(totalMinor, bps);
    case SplitMode.shares:
      final weights = [for (final id in ids) v(id)];
      if (weights.any((w) => w < 0)) return const SplitResult._([], "Shares can't be negative");
      if (weights.every((w) => w == 0)) return const SplitResult._([], 'Give someone at least 1 share');
      owed = _largestRemainder(totalMinor, weights);
    case SplitMode.adjust:
      final adj = [for (final id in ids) v(id)];
      final rest = totalMinor - adj.fold<int>(0, (a, b) => a + b);
      if (rest < 0) return SplitResult._(const [], 'Adjustments are ${_rupees(-rest)} more than the total');
      final base = _largestRemainder(rest, [for (final _ in ids) 1]);
      owed = [for (var i = 0; i < ids.length; i++) base[i] + adj[i]];
      if (owed.any((o) => o < 0)) return const SplitResult._([], "Someone's share went below ₹0");
  }

  final shares = <ExpenseShare>[
    for (var i = 0; i < ids.length; i++)
      ExpenseShare(userId: ids[i], paidMinor: ids[i] == payerId ? totalMinor : 0, owedMinor: owed[i]),
    // A payer who isn't sharing the cost still has to be on the expense.
    if (!ids.contains(payerId)) ExpenseShare(userId: payerId, paidMinor: totalMinor, owedMinor: 0),
  ];
  return SplitResult._(shares, null);
}

/// Splits [total] in proportion to [weights] in whole paise, handing the
/// leftover paise to the largest fractional parts (ties: first listed).
List<int> _largestRemainder(int total, List<int> weights) {
  final sum = weights.fold<int>(0, (a, b) => a + b);
  if (sum == 0) return [for (final _ in weights) 0];
  final exact = [for (final w in weights) total * w / sum];
  final floors = [for (final e in exact) e.floor()];
  var left = total - floors.fold<int>(0, (a, b) => a + b);
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final byFraction = (exact[b] - floors[b]).compareTo(exact[a] - floors[a]);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (final i in order) {
    if (left == 0) break;
    if (weights[i] == 0) continue;
    floors[i]++;
    left--;
  }
  return floors;
}
