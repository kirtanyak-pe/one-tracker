import 'package:flutter/widgets.dart';

import '../../engine/enrich.dart';
import '../../model/transaction.dart';
import '../../money.dart';
import '../../ui/format.dart';
import '../../ui/motion.dart';
import '../../ui/payee_logo.dart';

import 'package:onyx/onyx.dart';

import '../transaction_screen.dart';

/// Transactions grouped into one white card per day.
/// Newest-first payments grouped by day label ("Today", "Mon, 6 Oct").
List<({String label, List<Enriched> items})> groupByDay(List<Enriched> items, {bool grouped = true}) {
  final days = <String, List<Enriched>>{};
  for (final e in items) {
    days.putIfAbsent(grouped ? dayLabel(e.txn.at) : '', () => []).add(e);
  }
  return [for (final d in days.entries) (label: d.key, items: d.value)];
}

/// Transactions grouped into one white card per day. For short lists; long
/// ones use [groupByDay] + [TxnDayCard] in a lazy SliverList.
class TxnDayList extends StatelessWidget {
  const TxnDayList({super.key, required this.items, required this.currency, this.grouped = true});

  /// Newest first.
  final List<Enriched> items;
  final String currency;

  /// False shows one card with no day headers (e.g. "Biggest payments").
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final days = groupByDay(items, grouped: grouped);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, d) in days.indexed)
          TxnDayCard(label: grouped ? d.label : null, items: d.items, currency: currency, index: i),
      ],
    );
  }
}

/// One day's card: optional day label above, rows inside.
class TxnDayCard extends StatelessWidget {
  const TxnDayCard({super.key, required this.label, required this.items, required this.currency, this.index = 0});

  final String? label;
  final List<Enriched> items;
  final String currency;

  /// Position, for the staggered entrance.
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(OSpace.xs, OSpace.lg, OSpace.xs, OSpace.sm),
            child: Text(label!, style: text.small.copyWith(color: t.inkSoft)),
          ),
        FadeSlideIn(
          index: index,
          offset: 10,
          child: OCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const ODivider(indent: 72),
                  TxnRow(e: items[i], currency: currency),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.e, required this.currency});

  final Enriched e;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final credit = e.txn.direction == Direction.credit;
    final excluded = e.kind.excluded;
    final amount = '${credit ? '+' : ''}${formatMoney(e.txn.amountMinor, currency)}';

    return OPressable(
      onTap: () => pushScreen(context, TransactionScreen(id: e.txn.id)),
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.md),
        child: Row(
          children: [
            PayeeAvatar(e, size: 44, muted: excluded),
            const SizedBox(width: OSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.payee,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.title3.copyWith(color: excluded ? t.inkSoft : t.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [excluded ? e.kind.label : e.category.label, ...e.userTags.map((tag) => '#$tag')].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(color: t.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: OSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: text.title3.copyWith(
                    color: excluded
                        ? t.inkSoft
                        : credit
                        ? t.positive
                        : t.ink,
                    decoration: excluded ? TextDecoration.lineThrough : null,
                    decorationColor: t.inkSoft,
                  ),
                ),
                if (e.txn.countMonth case final month?) ...[const SizedBox(height: 4), _MovedChip(month: month)],
                if (e.needsReview) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "→ Nov": this payment counts in a later month than it was paid.
class _MovedChip extends StatelessWidget {
  const _MovedChip({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final label = '→ ${monthName(month).substring(0, 3)}';
    return Semantics(
      label: 'Counts in ${monthName(month)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OSpace.sm, vertical: 2),
        decoration: BoxDecoration(color: t.raised, borderRadius: BorderRadius.circular(ORadius.pill)),
        child: Text(label, style: context.type.small.copyWith(color: t.inkSoft, fontSize: 11)),
      ),
    );
  }
}
