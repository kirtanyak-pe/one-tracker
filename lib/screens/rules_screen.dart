import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../model/automation.dart';
import '../model/category.dart';
import '../model/transaction.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'widgets/category_pills.dart';

/// Automation: keyword rules you write, and payees you've taught it.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static Future<void> edit(BuildContext context, [AutoRule? rule]) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RuleEditor(rule: rule),
      );

  static Future<void> editPayee(BuildContext context, PayeeRule rule) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PayeeEditor(rule: rule),
      );

  static String _payeeSummary(PayeeRule r) => [
        if (r.name != null) 'Bank name: ${r.label}',
        if (r.category != null) r.category!.label,
        if (r.kind != null) r.kind!.label,
        ...r.tags.map((tag) => '#$tag'),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final payees = app.rules.values.toList()..sort((a, b) => (a.name ?? a.label).toLowerCase().compareTo((b.name ?? b.label).toLowerCase()));

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Rules'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
                  children: [
                    Text(
                      'Rules sort payments for you — past ones and every new one.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                    SectionHeader(
                      'Keyword rules',
                      top: Space.xl,
                      trailing: TextButton.icon(
                        onPressed: () => edit(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New'),
                      ),
                    ),
                    if (app.autoRules.isEmpty)
                      Tray(
                        child: Column(
                          children: [
                            Text(
                              'e.g. anything mentioning "zerodha" → Not an expense, '
                              'or "canteen" → Food & drinks #office.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(color: t.muted),
                            ),
                            const SizedBox(height: Space.md),
                            FilledButton(onPressed: () => edit(context), child: const Text('Create a rule')),
                          ],
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Column(
                          children: [
                            for (final (i, r) in app.autoRules.indexed) ...[
                              if (i > 0) Divider(height: 1, color: t.tray),
                              _RuleRow(
                                title: '"${r.contains}"',
                                subtitle: '${_matchCount(app, r)} payments · ${r.summary}',
                                onTap: () => edit(context, r),
                                onDelete: () => app.removeAutoRule(r.id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SectionHeader('Remembered payees'),
                    if (payees.isEmpty)
                      Tray(
                        child: Text(
                          'Rename a payee, tag all their payments, or turn on "Same for all" on any payment.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: t.muted),
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Column(
                          children: [
                            for (final (i, r) in payees.indexed) ...[
                              if (i > 0) Divider(height: 1, color: t.tray),
                              _RuleRow(
                                title: r.name ?? r.label,
                                subtitle: _payeeSummary(r),
                                onTap: () => editPayee(context, r),
                                onDelete: () {
                                  app.forget(r.key);
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(SnackBar(
                                      content: Text('Forgot ${r.name ?? r.label}'),
                                      action: SnackBarAction(label: 'Undo', onPressed: () => app.saveRule(r)),
                                    ));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _matchCount(AppController app, AutoRule r) => app.ledger.items
      .where((e) => r.matches('${e.txn.counterparty ?? ''} ${e.txn.vpa ?? ''} ${e.txn.raw ?? ''}'))
      .length;
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.title, required this.subtitle, required this.onDelete, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: t.muted)),
                ],
              ),
            ),
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.close), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.rule});

  final AutoRule? rule;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _contains = TextEditingController(text: widget.rule?.contains ?? '');
  late final _tag = TextEditingController(text: widget.rule?.tag ?? '');
  late Category? _category = widget.rule?.category;
  // -1 = leave as is.
  late int _kind = widget.rule?.kind?.index ?? -1;

  AutoRule get _draft => AutoRule(
        id: widget.rule?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        contains: _contains.text.trim(),
        category: _category,
        kind: _kind == -1 ? null : TxnKind.values[_kind],
        tag: _tag.text.trim().isEmpty ? null : _tag.text.trim(),
      );

  bool get _valid =>
      _contains.text.trim().length >= 2 && (_category != null || _kind != -1 || _tag.text.trim().isNotEmpty);

  @override
  void dispose() {
    _contains.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final matches = _contains.text.trim().length < 2 ? 0 : RulesScreen._matchCount(app, _draft);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.trayDeep, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(widget.rule == null ? 'New rule' : 'Edit rule', style: text.titleLarge),
                const SizedBox(height: Space.lg),
                Text('If a payment mentions', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                TextField(
                  controller: _contains,
                  autofocus: widget.rule == null,
                  decoration: const InputDecoration(hintText: 'e.g. zomato, canteen, rent'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  _contains.text.trim().length < 2
                      ? ' '
                      : 'Matches $matches payment${matches == 1 ? '' : 's'} so far',
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
                const SizedBox(height: Space.lg),
                Text('Count it as', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                PillSegmented<int>(
                  options: {
                    -1: 'Unchanged',
                    TxnKind.notExpense.index: 'Not expense',
                    TxnKind.selfTransfer.index: 'Self transfer',
                  },
                  value: _kind,
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(height: Space.lg),
                Text('Category (tap again to clear)', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                CategoryPills(
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c == _category ? null : c),
                ),
                const SizedBox(height: Space.lg),
                Text('Add tag', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                TextField(
                  controller: _tag,
                  decoration: const InputDecoration(hintText: 'Optional, e.g. Office'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _valid
                        ? () {
                            app.saveAutoRule(_draft);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(widget.rule == null ? 'Create rule' : 'Save rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edit what's remembered for one payee: its name and tags. Category and type
/// stay as set on the payment ("Same for all").
class _PayeeEditor extends StatefulWidget {
  const _PayeeEditor({required this.rule});

  final PayeeRule rule;

  @override
  State<_PayeeEditor> createState() => _PayeeEditorState();
}

class _PayeeEditorState extends State<_PayeeEditor> {
  late final _name = TextEditingController(text: widget.rule.name ?? '');
  final _newTag = TextEditingController();
  late List<String> _tags = [...widget.rule.tags];

  @override
  void dispose() {
    _name.dispose();
    _newTag.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _newTag.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags = [..._tags, tag];
      _newTag.clear();
    });
  }

  void _save() {
    _addTag();
    final name = _name.text.trim();
    final rule = widget.rule.copyWith(
      name: name.isEmpty || name == widget.rule.label ? null : name,
      clearName: name.isEmpty || name == widget.rule.label,
      tags: _tags,
    );
    final app = AppScope.of(context);
    if (rule.isEmpty) {
      app.forget(rule.key);
    } else {
      app.saveRule(rule);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rule = widget.rule;
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.trayDeep, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(rule.label, style: text.titleLarge),
                const SizedBox(height: Space.lg),
                Text('Show as', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: rule.label),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  name.isEmpty || name == rule.label
                      ? 'All payments to ${rule.label} show their bank name'
                      : 'All payments to ${rule.label} show as $name',
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
                const SizedBox(height: Space.lg),
                Text('Tags on all their payments', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        for (final tag in _tags)
                          Chip(
                            label: Text('#$tag'),
                            backgroundColor: t.card,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _tags = _tags.where((x) => x != tag).toList()),
                          ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _newTag,
                  decoration: InputDecoration(
                    hintText: 'Add a tag',
                    suffixIcon: IconButton(
                      tooltip: 'Add tag',
                      icon: const Icon(Icons.add),
                      onPressed: _addTag,
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
                const SizedBox(height: Space.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
