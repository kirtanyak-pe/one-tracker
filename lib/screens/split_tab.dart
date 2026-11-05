import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../money.dart';
import '../split/split_models.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/payee_logo.dart';

import 'package:onyx/onyx.dart';

import 'home_screen.dart' show push;
import 'settings/split_settings_page.dart';
import 'shell.dart';
import 'transaction_screen.dart';

/// Payments to hand to Splitwise (prefilled), and the ones already opened.
class SplitTab extends StatelessWidget {
  const SplitTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final todo = app.splitTodo;
    final history = app.splitRecords.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    final month = app.splitThisMonth;
    final todoTotal = todo.fold(0, (sum, e) => sum + e.txn.amountMinor);

    return OTabPage(
      title: 'Split',
      actions: [
        OIconButton(
          icon: LucideIcons.slidersHorizontal,
          label: 'Splitwise settings',
          filled: true,
          size: 44,
          onPressed: () => push(context, const SplitSettingsPage()),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.md, OSpace.gutter, navClearance),
        children: staggered([
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Opened this month',
                    value: formatCompact(month.totalMinor),
                    caption: '${month.count} payment${month.count == 1 ? '' : 's'}',
                  ),
                ),
                const SizedBox(width: OSpace.md),
                Expanded(
                  child: StatTile(
                    label: 'Waiting to split',
                    value: '${todo.length}',
                    caption: todo.isEmpty ? 'All caught up' : formatCompact(todoTotal),
                  ),
                ),
              ],
            ),
          ),
          OSectionHeader('To split', trailing: todo.isEmpty ? null : Text('${todo.length}', style: text.title3)),
          if (todo.isEmpty)
            OInset(
              padding: const EdgeInsets.all(OSpace.xl),
              radius: ORadius.lg,
              child: Text(
                'All caught up. New payments show up here.',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: t.inkSoft),
              ),
            )
          else
            _ToSplit(items: todo),
          if (history.isNotEmpty) ...[
            const OSectionHeader('Sent to Splitwise'),
            _History(records: history.take(10).toList()),
            Padding(
              padding: const EdgeInsets.only(top: OSpace.sm),
              child: Text(
                // Without the API the app only sees the tap that opened
                // Splitwise, never the saved expense or its group.
                "You opened these in Splitwise. One Tracker can't see if you saved them or which group you picked.",
                style: text.small.copyWith(color: t.inkSoft),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Payments still to split, the newest five until you ask for more.
class _ToSplit extends StatefulWidget {
  const _ToSplit({required this.items});

  final List<Enriched> items;

  @override
  State<_ToSplit> createState() => _ToSplitState();
}

class _ToSplitState extends State<_ToSplit> {
  static const _preview = 5;

  /// "Show more" adds this many at a time, so a long month never builds
  /// every row at once on a slow phone.
  static const _page = 20;
  int _limit = _preview;

  @override
  Widget build(BuildContext context) {
    final shown = widget.items.take(_limit).toList();
    final expanded = _limit > _preview;
    final hidden = widget.items.length - shown.length;
    return Column(
      children: [
        OCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, e) in shown.indexed) ...[
                if (i > 0) const ODivider(indent: 62),
                _ToSplitRow(key: ValueKey('split-${e.txn.id}'), e: e),
              ],
            ],
          ),
        ),
        if (hidden > 0)
          OTextButton(
            onPressed: () => setState(() => _limit += _page),
            label: hidden <= _page ? 'Show all $hidden more' : 'Show $_page more of $hidden',
          )
        else if (expanded)
          OTextButton(onPressed: () => setState(() => _limit = _preview), label: 'Show fewer'),
      ],
    );
  }
}

/// Short for a tight row: "20 min ago", "1:05 PM" (today), else "Yesterday".
String _when(DateTime at) {
  final full = friendlyTime(at);
  if (!full.contains(', ')) return full;
  return full.startsWith('Today, ') ? full.substring(7) : dayLabel(at);
}

/// One compact line: avatar · payee + time · amount · Split pill · Skip.
class _ToSplitRow extends StatelessWidget {
  const _ToSplitRow({super.key, required this.e});

  final Enriched e;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    return OPressable(
      onTap: () => push(context, TransactionScreen(id: e.txn.id)),
      pressedScale: 1,
      pressedOpacity: 0.6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.xs, OSpace.xs, OSpace.xs),
          child: Row(
            children: [
              PayeeAvatar(e, size: 36),
              const SizedBox(width: OSpace.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.title3),
                    Text(
                      _when(e.txn.at),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.small.copyWith(color: t.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OSpace.sm),
              Text(formatMoney(e.txn.amountMinor, appCurrency), maxLines: 1, style: text.title3.tabular),
              const SizedBox(width: OSpace.sm),
              _SplitPill(onPressed: () => app.openInSplitwise(e.txn.id)),
              OIconButton(
                icon: LucideIcons.x,
                label: 'Skip',
                size: 40,
                color: t.inkSoft,
                onPressed: () {
                  app.skipSplit(e.txn.id);
                  OToast.hide();
                  OToast.show(
                    context,
                    'Skipped ${e.payee}',
                    actionLabel: 'Undo',
                    onAction: () => app.undoSplit(e.txn.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small secondary pill; the tap area stays 48dp tall around it.
class _SplitPill extends StatelessWidget {
  const _SplitPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OButton.secondary(label: 'Split', size: OButtonSize.sm, onPressed: onPressed);
}

class _History extends StatelessWidget {
  const _History({required this.records});

  final List<SplitRecord> records;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    return OInset(
      padding: const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.xs),
      radius: ORadius.lg,
      child: Column(
        children: [
          for (final (i, r) in records.indexed) ...[
            if (i > 0) const ODivider(),
            OPressable(
              onTap: () => push(context, TransactionScreen(id: r.txnId)),
              pressedScale: 1,
              pressedOpacity: 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: OSpace.sm),
                child: Row(
                  children: [
                    OFinishBox(
                      color: t.surface,
                      depth: ODepth.surface,
                      shape: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 32,
                        child: Icon(LucideIcons.check, size: 18, color: t.positive),
                      ),
                    ),
                    const SizedBox(width: OSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.body),
                          Text(
                            'Opened ${friendlyTime(r.at)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.small.copyWith(color: t.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Text(formatMoney(r.amountMinor, appCurrency), style: text.body.tabular.semibold),
                    OTextButton(onPressed: () => app.undoSplit(r.txnId), label: 'Undo'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
