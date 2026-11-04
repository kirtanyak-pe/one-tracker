import '../engine/enrich.dart';
import 'split_models.dart';

/// What the user pressed on a split notification while the app wasn't looking
/// (queued natively, see SplitNotifications.kt).
enum SplitAction {
  split,
  skip,
  notExpense;

  static SplitAction? byName(String? name) => values.where((a) => a.name == name).firstOrNull;
}

class PendingSplitAction {
  const PendingSplitAction({required this.txnId, required this.action, required this.at});

  final String txnId;
  final SplitAction action;
  final DateTime at;

  /// From the channel: `{txnId, action, at (ms)}`. Null if malformed.
  static PendingSplitAction? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final txnId = raw['txnId'];
    final action = SplitAction.byName(raw['action'] as String?);
    final at = raw['at'];
    if (txnId is! String || action == null) return null;
    return PendingSplitAction(
      txnId: txnId,
      action: action,
      at: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : DateTime.now(),
    );
  }

  static List<PendingSplitAction> parseAll(Object? raw) =>
      raw is List ? [for (final r in raw) ?tryParse(r)] : const [];
}

/// Applies [actions] in order. Payments that no longer exist are ignored.
({Map<String, SplitRecord> records, Set<String> skipped, Set<String> notExpense, bool changed}) applySplitActions(
  Iterable<PendingSplitAction> actions, {
  required Map<String, SplitRecord> records,
  required Set<String> skipped,
  required Enriched? Function(String txnId) lookup,
  String groupName = 'Splitwise',
}) {
  final nextRecords = {...records};
  final nextSkipped = {...skipped};
  final notExpense = <String>{};
  var changed = false;
  for (final a in actions) {
    final e = lookup(a.txnId);
    if (e == null) continue;
    switch (a.action) {
      case SplitAction.split:
        nextRecords[a.txnId] = SplitRecord(
          txnId: a.txnId,
          label: groupName,
          amountMinor: e.txn.amountMinor,
          description: e.payee,
          at: a.at,
        );
        nextSkipped.remove(a.txnId);
        changed = true;
      case SplitAction.skip:
        if (!nextRecords.containsKey(a.txnId)) {
          nextSkipped.add(a.txnId);
          changed = true;
        }
      case SplitAction.notExpense:
        notExpense.add(a.txnId);
        nextSkipped.add(a.txnId);
        changed = true;
    }
  }
  return (records: nextRecords, skipped: nextSkipped, notExpense: notExpense, changed: changed);
}
