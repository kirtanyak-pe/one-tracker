import 'package:flutter/material.dart';

import '../../engine/enrich.dart';
import '../../ui/tokens.dart';

/// "to Maid ✎" with the bank's name underneath once it's been renamed.
/// Tapping it (or the pencil) renames the payee for all its payments.
class PayeeHeader extends StatelessWidget {
  const PayeeHeader({super.key, required this.prefix, required this.e, this.onRename});

  final String prefix;
  final Enriched e;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Semantics(
          button: onRename != null,
          label: 'Rename ${e.payee}',
          child: InkWell(
            onTap: onRename,
            borderRadius: BorderRadius.circular(Radii.tile),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '$prefix ${e.payee}',
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  if (onRename != null) ...[
                    const SizedBox(width: Space.sm),
                    Icon(Icons.edit_outlined, size: 16, color: t.muted),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (e.renamed)
          Text(
            'Bank name: ${e.originalPayee}',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
      ],
    );
  }
}

/// A row of tappable suggestion chips.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.items, required this.onPick});

  final List<String> items;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          for (final s in items)
            ActionChip(
              label: Text(s),
              visualDensity: VisualDensity.compact,
              onPressed: () => onPick(s),
            ),
        ],
      ),
    );
  }
}

/// Rename a payee. Pops the new name, '' to go back to the bank's name, or
/// null when cancelled.
class RenameDialog extends StatefulWidget {
  const RenameDialog({super.key, required this.original, required this.current, required this.suggestions});

  /// The name as the bank wrote it.
  final String original;

  /// The name the user gave it before ('' = none).
  final String current;
  final List<String> suggestions;

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final name = _controller.text.trim();
    return AlertDialog(
      title: const Text('Rename'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Maid, Cook, Blinkit'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: Space.sm),
            Text(
              name.isEmpty || name == widget.original
                  ? 'All payments to ${widget.original} will show their bank name'
                  : 'All payments to ${widget.original} will show as $name',
              style: text.bodySmall?.copyWith(color: t.muted),
            ),
            // In the body, not the actions: three buttons don't fit one row
            // and the dialog stacks them.
            if (widget.current.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('Use bank name'),
              ),
            _Suggestions(
              items: widget.suggestions,
              onPick: (s) => setState(() {
                _controller.value = TextEditingValue(
                  text: s,
                  selection: TextSelection.collapsed(offset: s.length),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}

/// Add a tag, by default to every payment to the payee.
class AddTagDialog extends StatefulWidget {
  const AddTagDialog({super.key, required this.payee, required this.canRemember, required this.suggestions});

  final String payee;

  /// False when there is no payee to remember it for.
  final bool canRemember;
  final List<String> suggestions;

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  final _controller = TextEditingController();
  var _forPayee = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String v) => Navigator.pop(context, (tag: v, forPayee: _forPayee && widget.canRemember));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Add tag'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Goa trip, Office'),
              onSubmitted: _submit,
            ),
            _Suggestions(
              items: widget.suggestions,
              onPick: (s) => setState(() {
                _controller.value = TextEditingValue(
                  text: s,
                  selection: TextSelection.collapsed(offset: s.length),
                );
              }),
            ),
            if (widget.canRemember) ...[
              const SizedBox(height: Space.md),
              CheckboxListTile(
                value: _forPayee,
                onChanged: (v) => setState(() => _forPayee = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('All payments to ${widget.payee}', style: text.bodyMedium),
                subtitle: Text(
                  _forPayee ? 'Past and future ones too' : 'Only this payment',
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => _submit(_controller.text), child: const Text('Add')),
      ],
    );
  }
}
