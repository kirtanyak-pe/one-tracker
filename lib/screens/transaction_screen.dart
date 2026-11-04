import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/payee_logo.dart';
import '../ui/tokens.dart';
import 'widgets/category_pills.dart';
import 'widgets/payee_dialogs.dart';

/// One transaction: what it counts as, its category and tags. Changes save
/// immediately.
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key, required this.id});

  final String id;

  Future<void> _addTag(BuildContext context, Enriched e) async {
    final app = AppScope.of(context);
    final result = await showDialog<({String tag, bool forPayee})>(
      context: context,
      builder: (_) => AddTagDialog(
        payee: e.payee,
        canRemember: app.canRename(e.txn),
        suggestions: app.knownTags.where((tag) => !e.tags.contains(tag)).take(8).toList(),
      ),
    );
    if (result != null && context.mounted) {
      await app.addTag(e.txn, result.tag, forPayee: result.forPayee);
    }
  }

  /// Rename the payee for all its payments. Empty result = back to bank name.
  Future<void> _rename(BuildContext context, Enriched e) async {
    final app = AppScope.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => RenameDialog(
        original: e.originalPayee,
        current: e.renamed ? e.payee : '',
        suggestions: {...app.knownNames, ...app.knownTags}
            .where((n) => n != e.payee)
            .take(10)
            .toList(),
      ),
    );
    if (name != null && context.mounted) await app.renamePayee(e, name);
  }

  Future<void> _removeTag(BuildContext context, Enriched e, String tag) async {
    final app = AppScope.of(context);
    if (!e.ruleTags.contains(tag)) return app.removeTag(e.txn, tag);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove #$tag?'),
        content: Text('It will come off every payment to ${e.payee}, not just this one.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && context.mounted) await app.removeTag(e.txn, tag);
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
                      child: PayeeAvatar(e, size: 56, background: t.card),
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
                    PayeeHeader(
                      prefix: credit ? 'from' : 'to',
                      e: e,
                      onRename: app.canRename(txn) ? () => _rename(context, e) : null,
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
                    if (e.countsAsSpend || txn.countMonth != null) ...[
                      const SizedBox(height: Space.xl),
                      _CountMonthRow(txn: txn),
                    ],
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
                            onRemove: e.userTags.contains(tag) ? () => _removeTag(context, e, tag) : null,
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Add tag'),
                          shape: StadiumBorder(side: BorderSide(color: t.trayDeep)),
                          backgroundColor: Colors.transparent,
                          onPressed: () => _addTag(context, e),
                        ),
                      ],
                    ),
                    if (e.ruleTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
                        child: Text(
                          '${e.ruleTags.map((tag) => '#$tag').join(' ')} '
                          '${e.ruleTags.length == 1 ? 'is' : 'are'} on all payments to ${e.payee}.',
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
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
                                  rule == null || !rule.hasClassification
                                      ? 'Apply this category and type to every payment to them'
                                      : 'On — ${_ruleSummary(rule)}',
                                  style: text.bodySmall?.copyWith(color: t.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: rule?.hasClassification ?? false,
                            activeTrackColor: t.ink,
                            onChanged: (on) => on ? app.rememberFor(e) : app.forgetClassification(rule!.key),
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

/// Counts this payment in the next month (bills paid on salary day), or
/// shows that it is and offers to move it back.
class _CountMonthRow extends StatelessWidget {
  const _CountMonthRow({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final moved = txn.countMonth != null;
    final paid = DateTime(txn.at.year, txn.at.month);
    final next = monthName(txn.nextMonth);

    return SurfaceCard(
      onTap: moved ? null : () => app.moveToNextMonth(txn.id),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                child: Icon(Icons.event_repeat_outlined, size: 20, color: t.ink),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moved ? 'Counts in $next · paid ${DateFormat('d MMM').format(txn.at)}' : 'Count in $next',
                      style: text.titleMedium,
                    ),
                    if (!moved)
                      Text(
                        'Paid on salary day? It belongs to next month.',
                        style: text.bodySmall?.copyWith(color: t.muted),
                      ),
                  ],
                ),
              ),
              if (!moved) Icon(Icons.chevron_right, color: t.muted),
            ],
          ),
          if (moved)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => app.moveBack(txn.id),
                child: Text('Move back to ${monthName(paid)}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Open this payment in Splitwise (prefilled), or show that it already was.
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
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.sm),
        radius: Radii.tile,
        child: Row(
          children: [
            Icon(Icons.check_circle, color: t.success),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text('Opened in Splitwise, ${friendlyTime(record.at)}', style: text.bodyMedium),
            ),
            TextButton(onPressed: () => app.undoSplit(e.txn.id), child: const Text('Undo')),
          ],
        ),
      );
    }
    return SurfaceCard(
      onTap: () => app.openInSplitwise(e.txn.id),
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
                Text('Split in Splitwise', style: text.titleMedium),
                Text(
                  'Opens it with ${formatMoney(e.txn.amountMinor, appCurrency)} filled in',
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
