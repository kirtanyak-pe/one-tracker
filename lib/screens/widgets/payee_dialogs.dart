import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../engine/enrich.dart';

import 'package:onyx/onyx.dart';

/// "to Maid ✎" with the bank's name underneath once it's been renamed.
/// Tapping it (or the pencil) renames the payee for all its payments.
class PayeeHeader extends StatelessWidget {
  const PayeeHeader({super.key, required this.prefix, required this.e, this.onRename});

  final String prefix;
  final Enriched e;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    return Column(
      children: [
        Semantics(
          button: onRename != null,
          label: 'Rename ${e.payee}',
          child: OPressable(
            onTap: onRename,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OSpace.md, vertical: OSpace.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text('$prefix ${e.payee}', textAlign: TextAlign.center, style: text.title3),
                  ),
                  if (onRename != null) ...[
                    const SizedBox(width: OSpace.sm),
                    Icon(LucideIcons.pencil, size: 16, color: t.inkSoft),
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
            style: text.small.copyWith(color: t.inkSoft),
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
      padding: const EdgeInsets.only(top: OSpace.md),
      child: Wrap(
        spacing: OSpace.sm,
        runSpacing: OSpace.xs,
        children: [for (final s in items) OChip(label: s, dense: true, onTap: () => onPick(s))],
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
    final t = context.colors;
    final text = context.type;
    final name = _controller.text.trim();
    return ODialog(
      title: 'Rename',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            placeholder: 'e.g. Maid, Cook, Blinkit',
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: OSpace.sm),
          Text(
            name.isEmpty || name == widget.original
                ? 'All payments to ${widget.original} will show their bank name'
                : 'All payments to ${widget.original} will show as $name',
            style: text.small.copyWith(color: t.inkSoft),
          ),
          if (widget.current.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OTextButton(label: 'Use bank name', onPressed: () => Navigator.pop(context, '')),
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
      actions: [
        OButton(label: 'Save', expand: true, onPressed: () => Navigator.pop(context, _controller.text)),
        OButton.ghost(label: 'Cancel', expand: true, onPressed: () => Navigator.pop(context)),
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
    return ODialog(
      title: 'Add tag',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            placeholder: 'e.g. Goa trip, Office',
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
            const SizedBox(height: OSpace.md),
            OCheckRow(
              value: _forPayee,
              onChanged: (v) => setState(() => _forPayee = v),
              title: 'All payments to ${widget.payee}',
              subtitle: _forPayee ? 'Past and future ones too' : 'Only this payment',
            ),
          ],
        ],
      ),
      actions: [
        OButton(label: 'Add', expand: true, onPressed: () => _submit(_controller.text)),
        OButton.ghost(label: 'Cancel', expand: true, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
