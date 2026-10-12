import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import 'split_tab.dart' show showSplitSheet;
import 'widgets/category_pills.dart';

/// One transaction: what it counts as, its category and tags. Changes save
/// immediately.
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key, required this.id});

  final String id;

  Future<void> _addTag(BuildContext context, Txn txn) async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Goa trip, Office'),
          onSubmitted: (v) => Navigator.pop(dialog, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (tag != null && context.mounted) await AppScope.of(context).addTag(txn, tag);
  }

  Future<void> _delete(BuildContext context, Txn txn) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('It may come back if the SMS is scanned again — mark it "Not expense" to hide it from spending instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pop(context);
      await AppScope.of(context).delete(txn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.find(id);
    if (e == null) return const Scaffold();
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final txn = e.txn;
    final credit = txn.direction == Direction.credit;
    final rule = app.ruleFor(txn);

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: credit ? 'Money in' : 'Payment',
                trailing: CircleIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, txn),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxxl),
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
                        child: Icon(e.category.icon, color: t.ink),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      '${credit ? '+' : ''}${formatMoney(txn.amountMinor, appCurrency)}',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        fontSize: 40,
                        color: e.kind.excluded ? t.muted : null,
                        decoration: e.kind.excluded ? TextDecoration.lineThrough : null,
                        decorationColor: t.muted,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${credit ? 'from' : 'to'} ${e.payee}',
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        friendlyTime(txn.at),
                        if (txn.account != null) '••${txn.account}',
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                    const SectionHeader('Counts as', top: Space.xxl),
                    PillSegmented<TxnKind>(
                      options: credit
                          ? const {
                              TxnKind.income: 'Income',
                              TxnKind.selfTransfer: 'Self transfer',
                              TxnKind.notExpense: 'Ignore',
                            }
                          : const {
                              TxnKind.expense: 'Expense',
                              TxnKind.selfTransfer: 'Self transfer',
                              TxnKind.notExpense: 'Not expense',
                            },
                      value: e.kind,
                      onChanged: (kind) => app.setKind(txn, kind),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
                      child: Text(
                        _kindNote(e),
                        style: text.bodySmall?.copyWith(color: t.muted),
                      ),
                    ),
                    if (e.countsAsSpend) ...[
                      const SizedBox(height: Space.xl),
                      _SplitRow(e: e),
                    ],
                    if (!credit) ...[
                      const SectionHeader('Category', top: Space.xxl),
                      CategoryPills(
                        selected: e.category,
                        onSelected: (c) => app.setCategory(txn, c),
                      ),
                    ],
                    const SectionHeader('Tags', top: Space.xxl),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final tag in e.tags)
                          _Tag(
                            label: tag,
                            onRemove: txn.userTags.contains(tag) ? () => app.removeTag(txn, tag) : null,
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Add tag'),
                          shape: StadiumBorder(side: BorderSide(color: t.trayDeep)),
                          backgroundColor: Colors.transparent,
                          onPressed: () => _addTag(context, txn),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xxl),
                    SurfaceCard(
                      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Same for all ${e.payee}', style: text.titleMedium),
                                Text(
                                  rule == null
                                      ? 'Apply this category and type to every payment to them'
                                      : 'On — ${_ruleSummary(rule)}',
                                  style: text.bodySmall?.copyWith(color: t.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: rule != null,
                            activeTrackColor: t.ink,
                            onChanged: (on) => on ? app.rememberFor(e) : app.forget(rule!.key),
                          ),
                        ],
                      ),
                    ),
                    if (txn.raw != null) ...[
                      const SectionHeader('Original message', top: Space.xxl),
                      Tray(
                        padding: const EdgeInsets.all(Space.lg),
                        radius: Radii.tile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sourceLabel(txn), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: Space.xs),
                            SelectableText(txn.raw!, style: text.bodySmall?.copyWith(color: t.muted)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _kindNote(Enriched e) {
    if (e.txn.kindOverride != null) return 'You set this.';
    if (e.reason != null) return 'Auto-detected: ${e.reason}.';
    return switch (e.kind) {
      TxnKind.expense => 'Counts towards your spending.',
      TxnKind.income => 'Counts as money in.',
      _ => 'Not counted as spending.',
    };
  }

  static String _ruleSummary(PayeeRule rule) => [
        if (rule.category != null) rule.category!.label,
        if (rule.kind != null) rule.kind!.label,
      ].join(' · ');
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Chip(
      label: Text('#$label'),
      backgroundColor: t.card,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteButtonTooltipMessage: 'Remove tag',
    );
  }
}

/// Split this payment on Splitwise, or show that it already was.
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.e});

  final Enriched e;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final record = app.splitRecords[e.txn.id];
    if (record != null) {
      return Tray(
        padding: const EdgeInsets.all(Space.lg),
        radius: Radii.tile,
        child: Row(
          children: [
            Icon(Icons.check_circle, color: t.success),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                'Split with ${record.label}${record.demo ? ' (demo)' : ''}, ${friendlyTime(record.at)}',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final target = app.splitTarget;
    return SurfaceCard(
      onTap: () => showSplitSheet(context, e),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.call_split, size: 20, color: t.accentDeep),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Split on Splitwise', style: text.titleMedium),
                Text(
                  target == null
                      ? 'Choose a group or friends'
                      : '${target.label}, ${formatMoney(target.shareOf(e.txn.amountMinor), appCurrency)} each',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.muted),
        ],
      ),
    );
  }
}
