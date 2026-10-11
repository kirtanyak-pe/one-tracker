import 'package:flutter/material.dart';

import '../../engine/enrich.dart';
import '../../model/transaction.dart';
import '../../money.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import '../transaction_screen.dart';

/// Transactions grouped into one white card per day.
class TxnDayList extends StatelessWidget {
  const TxnDayList({super.key, required this.items, required this.currency});

  /// Newest first.
  final List<Enriched> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final days = <String, List<Enriched>>{};
    for (final e in items) {
      days.putIfAbsent(dayLabel(e.txn.at), () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
            child: Text(day.key, style: text.bodySmall?.copyWith(color: t.muted)),
          ),
          Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(Radii.tile),
              boxShadow: Shadows.card(Theme.of(context).brightness),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < day.value.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 72, color: t.tray),
                  TxnRow(e: day.value[i], currency: currency),
                ],
              ],
            ),
          ),
        ],
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final credit = e.txn.direction == Direction.credit;
    final excluded = e.kind.excluded;
    final amount = '${credit ? '+' : ''}${formatMoney(e.txn.amountMinor, currency)}';

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TransactionScreen(id: e.txn.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                child: Icon(e.category.icon, size: 20, color: excluded ? t.muted : t.ink),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.payee,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(color: excluded ? t.muted : t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        excluded ? e.kind.label : e.category.label,
                        ...e.txn.userTags.map((tag) => '#$tag'),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: text.titleMedium?.copyWith(
                      color: excluded ? t.muted : credit ? t.success : t.ink,
                      decoration: excluded ? TextDecoration.lineThrough : null,
                      decorationColor: t.muted,
                    ),
                  ),
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
      ),
    );
  }
}
