import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../model/automation.dart';
import '../model/category.dart';
import '../model/transaction.dart';

import 'package:onyx/onyx.dart';

import 'widgets/category_pills.dart';

/// Automation: keyword rules you write, and payees you've taught it.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static Future<void> edit(BuildContext context, [AutoRule? rule]) =>
      showOSheet<void>(context, builder: (_) => _RuleEditor(rule: rule));

  static Future<void> editPayee(BuildContext context, PayeeRule rule) =>
      showOSheet<void>(context, builder: (_) => _PayeeEditor(rule: rule));

  static String _payeeSummary(PayeeRule r) => [
    if (r.name != null) 'Bank name: ${r.label}',
    if (r.category != null) r.category!.label,
    if (r.kind != null) r.kind!.label,
    ...r.tags.map((tag) => '#$tag'),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final payees = app.rules.values.toList()
      ..sort((a, b) => (a.name ?? a.label).toLowerCase().compareTo((b.name ?? b.label).toLowerCase()));

    return OScreen(
      title: 'Rules',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.xxxl),
        children: [
          Text(
            'Rules sort payments for you — past ones and every new one.',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          OSectionHeader(
            'Keyword rules',
            top: OSpace.xl,
            trailing: OTextButton(onPressed: () => edit(context), icon: LucideIcons.plus, label: 'New'),
          ),
          if (app.autoRules.isEmpty)
            OInset(
              child: Column(
                children: [
                  Text(
                    'e.g. anything mentioning "zerodha" → Not an expense, '
                    'or "canteen" → Food & drinks #office.',
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: t.inkSoft),
                  ),
                  const SizedBox(height: OSpace.md),
                  OButton(onPressed: () => edit(context), label: 'Create a rule'),
                ],
              ),
            )
          else
            OCard(
              padding: const EdgeInsets.symmetric(vertical: OSpace.xs),
              child: Column(
                children: [
                  for (final (i, r) in app.autoRules.indexed) ...[
                    if (i > 0) const ODivider(indent: OSpace.lg),
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
          const OSectionHeader('Remembered payees'),
          if (payees.isEmpty)
            OInset(
              child: Text(
                'Rename a payee, tag all their payments, or turn on "Same for all" on any payment.',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: t.inkSoft),
              ),
            )
          else
            OCard(
              padding: const EdgeInsets.symmetric(vertical: OSpace.xs),
              child: Column(
                children: [
                  for (final (i, r) in payees.indexed) ...[
                    if (i > 0) const ODivider(indent: OSpace.lg),
                    _RuleRow(
                      title: r.name ?? r.label,
                      subtitle: _payeeSummary(r),
                      onTap: () => editPayee(context, r),
                      onDelete: () {
                        app.forget(r.key);
                        OToast.show(
                          context,
                          'Forgot ${r.name ?? r.label}',
                          actionLabel: 'Undo',
                          onAction: () => app.saveRule(r),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
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
    final t = context.colors;
    final text = context.type;
    return OPressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.sm, OSpace.xs, OSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.title3),
                  Text(subtitle, style: text.small.copyWith(color: t.inkSoft)),
                ],
              ),
            ),
            OIconButton(icon: LucideIcons.x, label: 'Delete', onPressed: onDelete),
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
    final t = context.colors;
    final text = context.type;
    final matches = _contains.text.trim().length < 2 ? 0 : RulesScreen._matchCount(app, _draft);

    return OSheetBody(
      title: widget.rule == null ? 'New rule' : 'Edit rule',
      actions: [
        OButton(
          label: widget.rule == null ? 'Create rule' : 'Save rule',
          expand: true,
          onPressed: _valid
              ? () {
                  app.saveAutoRule(_draft);
                  Navigator.pop(context);
                }
              : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('If a payment mentions', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          OField(
            controller: _contains,
            autofocus: widget.rule == null,
            placeholder: 'e.g. zomato, canteen, rent',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OSpace.xs),
          Text(
            _contains.text.trim().length < 2 ? ' ' : 'Matches $matches payment${matches == 1 ? '' : 's'} so far',
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const SizedBox(height: OSpace.lg),
          Text('Count it as', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          OSegmented<int>(
            values: [-1, TxnKind.notExpense.index, TxnKind.selfTransfer.index],
            selected: _kind,
            labelOf: (v) => v == -1
                ? 'Unchanged'
                : v == TxnKind.notExpense.index
                ? 'Not expense'
                : 'Self transfer',
            onChanged: (v) => setState(() => _kind = v),
          ),
          const SizedBox(height: OSpace.lg),
          Text('Category (tap again to clear)', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          CategoryPills(selected: _category, onSelected: (c) => setState(() => _category = c == _category ? null : c)),
          const SizedBox(height: OSpace.lg),
          Text('Add tag', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          OField(controller: _tag, placeholder: 'Optional, e.g. Office', onChanged: (_) => setState(() {})),
        ],
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
    final t = context.colors;
    final text = context.type;
    final rule = widget.rule;
    final name = _name.text.trim();
    return OSheetBody(
      title: rule.label,
      actions: [OButton(label: 'Save', expand: true, onPressed: _save)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Show as', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          OField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            placeholder: rule.label,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OSpace.xs),
          Text(
            name.isEmpty || name == rule.label
                ? 'All payments to ${rule.label} show their bank name'
                : 'All payments to ${rule.label} show as $name',
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const SizedBox(height: OSpace.lg),
          Text('Tags on all their payments', style: text.small.copyWith(color: t.inkSoft)),
          const SizedBox(height: OSpace.sm),
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: OSpace.sm),
              child: Wrap(
                spacing: OSpace.sm,
                runSpacing: OSpace.xs,
                children: [
                  for (final tag in _tags)
                    OChip(
                      label: '#$tag',
                      trailingIcon: LucideIcons.x,
                      onTap: () => setState(() => _tags = _tags.where((x) => x != tag).toList()),
                    ),
                ],
              ),
            ),
          OField(
            controller: _newTag,
            placeholder: 'Add a tag',
            suffix: OIconButton(icon: LucideIcons.plus, label: 'Add tag', onPressed: _addTag),
            onSubmitted: (_) => _addTag(),
          ),
        ],
      ),
    );
  }
}
