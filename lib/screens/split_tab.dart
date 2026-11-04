import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../money.dart';
import '../split/split_models.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/payee_logo.dart';
import '../ui/tokens.dart';
import 'home_screen.dart' show push;
import 'settings/split_settings_page.dart';
import 'shell.dart';

/// Payments to hand to Splitwise (prefilled), and the ones already opened.
class SplitTab extends StatelessWidget {
  const SplitTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final todo = app.splitTodo;
    final history = app.splitRecords.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    final month = app.splitThisMonth;
    final todoTotal = todo.fold(0, (sum, e) => sum + e.txn.amountMinor);

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, navClearance),
          children: staggered([
            Row(
              children: [
                Expanded(child: Text('Splitwise', style: text.titleMedium?.copyWith(color: t.muted))),
                CircleIconButton(
                  icon: Icons.tune,
                  tooltip: 'Splitwise settings',
                  onPressed: () => push(context, const SplitSettingsPage()),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
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
                  const SizedBox(width: Space.md),
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
            SectionHeader(
              'To split',
              trailing: todo.isEmpty ? null : Text('${todo.length}', style: text.titleMedium),
            ),
            if (todo.isEmpty)
              Tray(
                child: Text(
                  'All caught up. New payments show up here.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: t.muted),
                ),
              )
            else
              _ToSplit(items: todo),
            if (history.isNotEmpty) ...[
              const SectionHeader('Opened in Splitwise'),
              _History(records: history.take(10).toList()),
            ],
          ]),
        ),
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
    final t = context.tokens;
    final shown = widget.items.take(_limit).toList();
    final expanded = _limit > _preview;
    final hidden = widget.items.length - shown.length;
    return Column(
      children: [
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, e) in shown.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 62, color: t.tray),
                _ToSplitRow(key: ValueKey('split-${e.txn.id}'), e: e),
              ],
            ],
          ),
        ),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _limit += _page),
            child: Text(hidden <= _page ? 'Show all $hidden more' : 'Show $_page more of $hidden'),
          )
        else if (expanded)
          TextButton(onPressed: () => setState(() => _limit = _preview), child: const Text('Show fewer')),
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
        child: Row(
          children: [
            PayeeAvatar(e, size: 36),
            const SizedBox(width: Space.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                  Text(
                    _when(e.txn.at),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              formatMoney(e.txn.amountMinor, appCurrency),
              maxLines: 1,
              style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: Space.sm),
            _SplitPill(onPressed: () => app.openInSplitwise(e.txn.id)),
            Tooltip(
              message: 'Skip',
              child: InkResponse(
                radius: 24,
                onTap: () {
                  app.skipSplit(e.txn.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('Skipped ${e.payee}'),
                        action: SnackBarAction(label: 'Undo', onPressed: () => app.undoSplit(e.txn.id)),
                      ),
                    );
                },
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(Icons.close, size: 20, color: t.muted, semanticLabel: 'Skip'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tonal accent pill; the tap area is 48dp tall around a 34dp pill.
class _SplitPill extends StatelessWidget {
  const _SplitPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? t.accent : t.accentDeep;
    return Semantics(
      button: true,
      label: 'Split',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: DecoratedBox(
              decoration: ShapeDecoration(color: fg.withValues(alpha: dark ? 0.18 : 0.12), shape: const StadiumBorder()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Text(
                  'Split',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.records});

  final List<SplitRecord> records;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Tray(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      radius: Radii.tile,
      child: Column(
        children: [
          for (final (i, r) in records.indexed) ...[
            if (i > 0) Divider(height: 1, color: t.trayDeep),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 18, color: t.success),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text(
                          '${r.label} · ${friendlyTime(r.at)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(r.amountMinor, appCurrency),
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  TextButton(onPressed: () => app.undoSplit(r.txnId), child: const Text('Undo')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
