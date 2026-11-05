import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/format.dart';
import '../ui/payee_logo.dart';

import 'package:onyx/onyx.dart';

import 'widgets/category_pills.dart';
import 'widgets/payee_dialogs.dart';

/// One transaction: what it counts as, its category and tags. Changes save
/// immediately.
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key, required this.id});

  final String id;

  Future<void> _addTag(BuildContext context, Enriched e) async {
    final app = AppScope.of(context);
    final result = await showODialog<({String tag, bool forPayee})>(
      context,
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
    final name = await showODialog<String>(
      context,
      builder: (_) => RenameDialog(
        original: e.originalPayee,
        current: e.renamed ? e.payee : '',
        suggestions: {...app.knownNames, ...app.knownTags}.where((n) => n != e.payee).take(10).toList(),
      ),
    );
    if (name != null && context.mounted) await app.renamePayee(e, name);
  }

  Future<void> _removeTag(BuildContext context, Enriched e, String tag) async {
    final app = AppScope.of(context);
    if (!e.ruleTags.contains(tag)) return app.removeTag(e.txn, tag);
    final ok = await showOConfirm(
      context,
      title: 'Remove #$tag?',
      message: 'It will come off every payment to ${e.payee}, not just this one.',
      confirm: 'Remove',
    );
    if (ok && context.mounted) await app.removeTag(e.txn, tag);
  }

  Future<void> _delete(BuildContext context, Txn txn) async {
    final ok = await showOConfirm(
      context,
      title: 'Delete transaction?',
      message: 'It may come back if the SMS is scanned again — mark it "Not expense" to hide it from spending instead.',
      confirm: 'Delete',
      destructive: true,
    );
    if (ok && context.mounted) {
      Navigator.pop(context);
      await AppScope.of(context).delete(txn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final e = app.find(id);
    if (e == null) return const OScreen(body: SizedBox.shrink());
    final t = context.colors;
    final text = context.type;
    final txn = e.txn;
    final credit = txn.direction == Direction.credit;
    final rule = app.ruleFor(txn);

    final kindOptions = credit
        ? const {TxnKind.income: 'Income', TxnKind.selfTransfer: 'Self transfer', TxnKind.notExpense: 'Ignore'}
        : const {TxnKind.expense: 'Expense', TxnKind.selfTransfer: 'Self transfer', TxnKind.notExpense: 'Not expense'};

    return OScreen(
      title: credit ? 'Money in' : 'Payment',
      trailing: OIconButton(
        icon: LucideIcons.trash2,
        label: 'Delete',
        filled: true,
        size: 44,
        onPressed: () => _delete(context, txn),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.xxxl),
        children: [
          Center(child: PayeeAvatar(e, size: 56, background: t.surface)),
          const SizedBox(height: OSpace.md),
          Text(
            '${credit ? '+' : ''}${formatMoney(txn.amountMinor, appCurrency)}',
            textAlign: TextAlign.center,
            style: text.display.tabular.copyWith(
              color: e.kind.excluded ? t.inkSoft : null,
              decoration: e.kind.excluded ? TextDecoration.lineThrough : null,
              decorationColor: t.inkSoft,
            ),
          ),
          const SizedBox(height: OSpace.xs),
          PayeeHeader(
            prefix: credit ? 'from' : 'to',
            e: e,
            onRename: app.canRename(txn) ? () => _rename(context, e) : null,
          ),
          const SizedBox(height: 2),
          Text(
            [friendlyTime(txn.at), if (txn.account != null) '••${txn.account}'].join(' · '),
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const OSectionHeader('Counts as', top: OSpace.xxl),
          OSegmented<TxnKind>(
            values: kindOptions.keys.toList(),
            selected: e.kind,
            labelOf: (v) => kindOptions[v]!,
            onChanged: (kind) => app.setKind(txn, kind),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(OSpace.xs, OSpace.sm, OSpace.xs, 0),
            child: Text(_kindNote(e), style: text.small.copyWith(color: t.inkSoft)),
          ),
          if (e.countsAsSpend || txn.countMonth != null) ...[
            const SizedBox(height: OSpace.xl),
            _CountMonthRow(txn: txn),
          ],
          if (e.countsAsSpend) ...[const SizedBox(height: OSpace.xl), _SplitRow(e: e)],
          if (!credit) ...[
            const OSectionHeader('Category', top: OSpace.xxl),
            CategoryPills(selected: e.category, onSelected: (c) => app.setCategory(txn, c)),
          ],
          const OSectionHeader('Tags', top: OSpace.xxl),
          Wrap(
            spacing: OSpace.sm,
            runSpacing: OSpace.sm,
            children: [
              for (final tag in e.tags)
                _Tag(label: tag, onRemove: e.userTags.contains(tag) ? () => _removeTag(context, e, tag) : null),
              OChip(icon: LucideIcons.plus, label: 'Add tag', onTap: () => _addTag(context, e)),
            ],
          ),
          if (e.ruleTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(OSpace.xs, OSpace.sm, OSpace.xs, 0),
              child: Text(
                '${e.ruleTags.map((tag) => '#$tag').join(' ')} '
                '${e.ruleTags.length == 1 ? 'is' : 'are'} on all payments to ${e.payee}.',
                style: text.small.copyWith(color: t.inkSoft),
              ),
            ),
          const SizedBox(height: OSpace.xxl),
          OCard(
            padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.md, OSpace.lg, OSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Same for all ${e.payee}', style: text.title3),
                      Text(
                        rule == null || !rule.hasClassification
                            ? 'Apply this category and type to every payment to them'
                            : 'On — ${_ruleSummary(rule)}',
                        style: text.small.copyWith(color: t.inkSoft),
                      ),
                    ],
                  ),
                ),
                OToggle(
                  value: rule?.hasClassification ?? false,
                  onChanged: (on) => on ? app.rememberFor(e) : app.forgetClassification(rule!.key),
                ),
              ],
            ),
          ),
          if (txn.raw != null) ...[
            const OSectionHeader('Original message', top: OSpace.xxl),
            OInset(
              padding: const EdgeInsets.all(OSpace.lg),
              radius: ORadius.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sourceLabel(txn), style: text.small.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: OSpace.xs),
                  Text(txn.raw!, style: text.small.copyWith(color: t.inkSoft)),
                ],
              ),
            ),
          ],
        ],
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

  static String _ruleSummary(PayeeRule rule) =>
      [if (rule.category != null) rule.category!.label, if (rule.kind != null) rule.kind!.label].join(' · ');
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: onRemove == null ? null : 'Remove tag',
      child: OChip(label: '#$label', trailingIcon: onRemove == null ? null : LucideIcons.x, onTap: onRemove),
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
    final t = context.colors;
    final text = context.type;
    final moved = txn.countMonth != null;
    final paid = DateTime(txn.at.year, txn.at.month);
    final next = monthName(txn.nextMonth);

    return OCard(
      onTap: moved ? null : () => app.moveToNextMonth(txn.id),
      padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.md, OSpace.md, OSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle),
                child: Icon(LucideIcons.calendarSync, size: 20, color: t.ink),
              ),
              const SizedBox(width: OSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moved ? 'Counts in $next · paid ${DateFormat('d MMM').format(txn.at)}' : 'Count in $next',
                      style: text.title3,
                    ),
                    if (!moved)
                      Text(
                        'Paid on salary day? It belongs to next month.',
                        style: text.small.copyWith(color: t.inkSoft),
                      ),
                  ],
                ),
              ),
              if (!moved) Icon(LucideIcons.chevronRight, size: 20, color: t.inkSoft),
            ],
          ),
          if (moved)
            Align(
              alignment: Alignment.centerRight,
              child: OTextButton(onPressed: () => app.moveBack(txn.id), label: 'Move back to ${monthName(paid)}'),
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
    final t = context.colors;
    final text = context.type;
    final record = app.splitRecords[e.txn.id];
    if (record != null) {
      return OInset(
        padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.sm, OSpace.sm, OSpace.sm),
        radius: ORadius.lg,
        child: Row(
          children: [
            Icon(LucideIcons.circleCheck, size: 20, color: t.positive),
            const SizedBox(width: OSpace.md),
            Expanded(child: Text('Opened in Splitwise, ${friendlyTime(record.at)}', style: text.body)),
            OTextButton(onPressed: () => app.undoSplit(e.txn.id), label: 'Undo'),
          ],
        ),
      );
    }
    return OCard(
      onTap: () => app.openInSplitwise(e.txn.id),
      padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.md, OSpace.md, OSpace.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle),
            child: Icon(LucideIcons.split, size: 20, color: t.ink),
          ),
          const SizedBox(width: OSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Split in Splitwise', style: text.title3),
                Text(
                  'Opens it with ${formatMoney(e.txn.amountMinor, appCurrency)} filled in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(color: t.inkSoft),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 20, color: t.inkSoft),
        ],
      ),
    );
  }
}
