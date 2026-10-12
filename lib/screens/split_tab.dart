import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../money.dart';
import '../split/split_card.dart';
import '../split/split_models.dart';
import '../splitwise/models.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'home_screen.dart' show push;
import 'settings/split_settings_page.dart';
import 'shell.dart';

/// Opens the split card as a sheet inside the app.
Future<void> showSplitSheet(BuildContext context, Enriched payment) {
  final app = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        // Capped: the card scrolls its picker and keeps the buttons in view.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
          child: SplitCard(
            prompt: AppController.promptFor(payment),
            groups: app.swGroups,
            friends: app.swFriends,
            defaultTarget: app.splitTarget,
            demo: !app.swConnected,
            onSplit: (target, makeDefault) => app.split(payment, target, makeDefault: makeDefault),
            onDismiss: () => Navigator.pop(sheet),
          ),
        ),
      ),
    ),
  );
}

class SplitTab extends StatelessWidget {
  const SplitTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final todo = app.splitTodo;
    final history = app.splitRecords.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    final owesYou = app.swFriends.where((f) => f.balanceMinor > 0).toList()
      ..sort((a, b) => b.balanceMinor.compareTo(a.balanceMinor));
    final youOwe = app.swFriends.where((f) => f.balanceMinor < 0).toList()
      ..sort((a, b) => a.balanceMinor.compareTo(b.balanceMinor));
    final month = app.splitThisMonth;
    final todoTotal = todo.fold(0, (sum, e) => sum + e.txn.amountMinor);

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.ink,
          onRefresh: app.refreshSplitwise,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, navClearance),
            children: staggered([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.swConnected ? 'Splitwise' : 'Splitwise · demo',
                      style: text.titleMedium?.copyWith(color: t.muted),
                    ),
                  ),
                  if (app.swLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.md),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
                      ),
                    ),
                  CircleIconButton(
                    icon: Icons.tune,
                    tooltip: 'Splitwise settings',
                    onPressed: () => push(context, const SplitSettingsPage()),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              _Balance(app: app),
              const SizedBox(height: Space.xxl),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Split this month',
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
              if (app.splitTarget == null) ...[
                const SizedBox(height: Space.lg),
                Tray(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Set a default split', style: text.titleMedium),
                            Text(
                              'Then splitting after you pay is one tap.',
                              style: text.bodySmall?.copyWith(color: t.muted),
                            ),
                          ],
                        ),
                      ),
                      AccentOrb(
                        icon: Icons.groups_outlined,
                        tooltip: 'Set default split',
                        onPressed: () => push(context, const SplitSettingsPage()),
                      ),
                    ],
                  ),
                ),
              ],
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
                _ToSplit(items: todo.take(10).toList()),
              if (owesYou.isNotEmpty) ...[
                const SectionHeader('Owes you'),
                _People(people: owesYou.take(5).toList(), positive: true),
              ],
              if (youOwe.isNotEmpty) ...[
                const SectionHeader('You owe'),
                _People(people: youOwe.take(5).toList(), positive: false),
              ],
              if (history.isNotEmpty) ...[
                const SectionHeader('Split history'),
                _History(records: history.take(10).toList()),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Net balance as the headline: green when you're owed, red when you owe.
class _Balance extends StatelessWidget {
  const _Balance({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final net = app.owedToYouMinor - app.youOweMinor;
    final red = Theme.of(context).colorScheme.error;
    final color = net > 0
        ? t.success
        : net < 0
        ? red
        : t.ink;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedMoney(net.abs(), round: true, style: text.displaySmall?.copyWith(fontSize: 48, color: color)),
        ),
        const SizedBox(height: Space.xs),
        Text(
          net > 0
              ? "you're owed in total"
              : net < 0
              ? 'you owe in total'
              : app.swFriends.isEmpty
              ? 'connect Splitwise to see balances'
              : "you're all settled up",
          style: text.bodyLarge?.copyWith(color: t.muted),
        ),
        if (app.owedToYouMinor > 0 && app.youOweMinor > 0) ...[
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: t.success),
              Text(
                ' ${formatMoney(app.owedToYouMinor, appCurrency, round: true)} owed to you',
                style: text.bodySmall?.copyWith(color: t.muted),
              ),
              const SizedBox(width: Space.lg),
              _Dot(color: red),
              Text(
                ' ${formatMoney(app.youOweMinor, appCurrency, round: true)} you owe',
                style: text.bodySmall?.copyWith(color: t.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _People extends StatelessWidget {
  const _People({required this.people, required this.positive});

  final List<SwUser> people;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = positive ? t.success : Theme.of(context).colorScheme.error;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      child: Column(
        children: [
          for (final (i, p) in people.indexed) ...[
            if (i > 0) Divider(height: 1, color: t.tray),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Avatar(p.name),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                  ),
                  Text(
                    formatMoney(p.balanceMinor.abs(), appCurrency),
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToSplit extends StatelessWidget {
  const _ToSplit({required this.items});

  final List<Enriched> items;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        children: [
          for (final (i, e) in items.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 72, color: t.tray),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.xs, Space.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                    child: Icon(e.category.icon, size: 20, color: t.ink),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                        Text(
                          '${formatMoney(e.txn.amountMinor, appCurrency)} · ${friendlyTime(e.txn.at)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => showSplitSheet(context, e),
                    style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                    child: const Text('Split'),
                  ),
                  IconButton(
                    tooltip: 'Not this one',
                    onPressed: () => app.skipSplit(e),
                    icon: Icon(Icons.close, color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.records});

  final List<SplitRecord> records;

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(vertical: Space.md),
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
                        Text(r.description, style: text.bodyMedium),
                        Text(
                          '${r.label} · ${friendlyTime(r.at)}${r.demo ? ' · demo' : ''}',
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
