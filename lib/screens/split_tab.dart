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
import 'shell.dart';

/// Opens the split card as a sheet inside the app.
Future<void> showSplitSheet(BuildContext context, Enriched payment) {
  final app = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.md),
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

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.ink,
          onRefresh: app.refreshSplitwise,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, navClearance),
            children: staggered([
              Text('Split', style: text.headlineMedium),
              const SizedBox(height: Space.xs),
              Text(
                'Pay, then split on Splitwise in one tap.',
                style: text.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: Space.xl),
              _Connection(app: app),
              const SectionHeader('Default split'),
              _DefaultTarget(app: app),
              const SectionHeader('When you pay'),
              _WhenYouPay(app: app),
              SectionHeader('To split', trailing: todo.isEmpty ? null : Text('${todo.length}', style: text.titleMedium)),
              if (todo.isEmpty)
                Tray(
                  child: Text(
                    'All caught up. New payments show up here.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: t.muted),
                  ),
                )
              else
                _ToSplit(items: todo.take(20).toList()),
              if (history.isNotEmpty) ...[
                const SectionHeader('Split history'),
                _History(records: history.take(15).toList()),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Connection extends StatefulWidget {
  const _Connection({required this.app});

  final AppController app;

  @override
  State<_Connection> createState() => _ConnectionState();
}

class _ConnectionState extends State<_Connection> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.app.connectSplitwise(_key.text);
      _key.clear();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (app.swConnected) {
      return SurfaceCard(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.lg),
        child: Row(
          children: [
            Avatar(app.swUser?.user.name ?? '?', size: 44),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.swUser?.user.name ?? 'Splitwise', style: text.titleMedium),
                  Text(
                    app.swError ?? '${app.swGroups.length} groups, ${app.swFriends.length} friends',
                    style: text.bodySmall?.copyWith(
                      color: app.swError != null ? Theme.of(context).colorScheme.error : t.muted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: app.disconnectSplitwise, child: const Text('Disconnect')),
          ],
        ),
      );
    }

    return Tray(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect Splitwise', style: text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            'Until then you can try it with demo groups. Nothing is sent.',
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: Space.md),
          const _Step(1, 'On a computer, open secure.splitwise.com/apps'),
          const _Step(2, 'Register your application (any name and URL)'),
          const _Step(3, 'Create an API key and paste it here'),
          const SizedBox(height: Space.md),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            decoration: InputDecoration(hintText: 'Paste API key', errorText: _error),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy || _key.text.trim().isEmpty ? null : _connect,
              child: Text(_busy ? 'Checking…' : 'Connect'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.label);

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
            child: Text('$number', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _DefaultTarget extends StatelessWidget {
  const _DefaultTarget({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final target = app.splitTarget;
    return SurfaceCard(
      onTap: () => _pickTarget(context),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
            child: Icon(
              target?.kind == TargetKind.friends ? Icons.people_outline : Icons.groups_outlined,
              color: t.ink,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(target?.label ?? 'Not set', style: text.titleMedium),
                Text(
                  target == null
                      ? "Pick who you usually split with, so it's one tap"
                      : '${target.people} people, split equally',
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _pickTarget(context),
            style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
            child: Text(target == null ? 'Choose' : 'Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTarget(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _TargetSheet(app: app),
      );
}

/// Pick the default: one group, or several friends.
class _TargetSheet extends StatefulWidget {
  const _TargetSheet({required this.app});

  final AppController app;

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  late SplitTarget? _target = widget.app.splitTarget;
  late final Set<int> _friendIds = {...?widget.app.splitTarget?.friendIds};

  void _toggle(SwUser f) => setState(() {
        _friendIds.contains(f.id) ? _friendIds.remove(f.id) : _friendIds.add(f.id);
        final picked = widget.app.swFriends.where((x) => _friendIds.contains(x.id)).toList();
        _target = picked.isEmpty ? null : SplitTarget.friends(picked);
      });

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Space.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: t.trayDeep, borderRadius: BorderRadius.circular(2)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.md),
                children: [
                  Text('Default split', style: text.titleLarge),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Every new payment will suggest this. You can still change it on the card.',
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                  if (app.swGroups.isNotEmpty) ...[
                    const SectionHeader('Groups', top: Space.xl),
                    for (final g in app.swGroups) ...[
                      SurfaceCard(
                        selected: _target?.kind == TargetKind.group && _target?.groupId == g.id,
                        onTap: () => setState(() {
                          _friendIds.clear();
                          _target = SplitTarget.group(g);
                        }),
                        padding: const EdgeInsets.all(Space.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.name, style: text.titleMedium),
                                  Text('${g.members.length} people', style: text.bodySmall?.copyWith(color: t.muted)),
                                ],
                              ),
                            ),
                            AvatarStack(g.members.map((m) => m.name).toList()),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                  if (app.swFriends.isNotEmpty) ...[
                    const SectionHeader('Or friends', top: Space.lg),
                    for (final f in app.swFriends) ...[
                      SurfaceCard(
                        selected: _friendIds.contains(f.id),
                        onTap: () => _toggle(f),
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                        child: Row(
                          children: [
                            Avatar(f.name),
                            const SizedBox(width: Space.md),
                            Expanded(child: Text(f.name, style: text.titleMedium)),
                            Icon(
                              _friendIds.contains(f.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: _friendIds.contains(f.id) ? t.ink : t.trayDeep,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: Row(
                children: [
                  if (app.splitTarget != null)
                    TextButton(
                      onPressed: () {
                        app.setSplitTarget(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _target == null
                        ? null
                        : () {
                            app.setSplitTarget(_target);
                            Navigator.pop(context);
                          },
                    child: Text(_target == null ? 'Save' : 'Save: ${_target!.label}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhenYouPay extends StatelessWidget {
  const _WhenYouPay({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = app.splitSettings;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask me to split', style: text.titleMedium),
                    Text('Right after each new payment', style: text.bodySmall?.copyWith(color: t.muted)),
                  ],
                ),
              ),
              Switch(
                value: s.popup,
                activeTrackColor: t.ink,
                onChanged: (v) => app.setSplitSettings(s.copyWith(popup: v)),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text('Only for payments above', style: text.bodySmall?.copyWith(color: t.muted)),
          const SizedBox(height: Space.sm),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: PillSegmented<int>(
              options: const {0: 'Any', 10000: '₹100', 50000: '₹500', 100000: '₹1k'},
              value: s.minMinor,
              onChanged: (v) => app.setSplitSettings(s.copyWith(minMinor: v)),
            ),
          ),
          if (app.isAndroid) ...[
            const SizedBox(height: Space.lg),
            Divider(height: 1, color: t.tray),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Float over other apps', style: text.titleMedium),
                      Text(
                        app.overlayGranted
                            ? 'The card pops up wherever you paid'
                            : 'Needed for the pop-up after you pay',
                        style: text.bodySmall?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                if (app.overlayGranted)
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await app.previewFloatingCard();
                      if (!ok) messenger.showSnackBar(const SnackBar(content: Text('No payment to preview yet')));
                    },
                    child: const Text('Preview'),
                  )
                else
                  FilledButton(
                    onPressed: app.requestOverlay,
                    style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                    child: const Text('Allow'),
                  ),
              ],
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
