import '../engine/enrich.dart';
import 'split_models.dart';

/// Payments worth offering to split: real spending above the minimum,
/// not already split or skipped. Newest first.
List<Enriched> splitCandidates(
  Iterable<Enriched> items, {
  required Set<String> handled,
  required SplitSettings settings,
  DateTime? since,
}) =>
    items
        .where((e) =>
            e.countsAsSpend &&
            e.txn.amountMinor > settings.minMinor &&
            !handled.contains(e.txn.id) &&
            (since == null || !e.txn.at.isBefore(since)))
        .toList()
      ..sort((a, b) => b.txn.at.compareTo(a.txn.at));

/// The one payment to pop up about right now, from those just detected.
/// Only fresh ones (≤ 30 min old), so a backfill scan never triggers it.
Enriched? popupFor(
  Iterable<Enriched> justAdded, {
  required Set<String> handled,
  required SplitSettings settings,
  required DateTime now,
}) {
  if (!settings.popup) return null;
  return splitCandidates(
    justAdded,
    handled: handled,
    settings: settings,
    since: now.subtract(const Duration(minutes: 30)),
  ).firstOrNull;
}
