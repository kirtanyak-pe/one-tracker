import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../detection/detected_payment.dart';
import '../money.dart';
import '../splitwise/models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

enum _SplitWith { group, friends }

/// Full split form: any amount, a group or a hand-picked set of friends.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key, this.payment});

  /// Pre-fills the form when splitting a detected payment.
  final DetectedPayment? payment;

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  late final _amount = TextEditingController(
    text: widget.payment == null ? '' : minorToDecimal(widget.payment!.amountMinor),
  );
  late final _description = TextEditingController(text: widget.payment?.merchant ?? '');
  var _splitWith = _SplitWith.group;
  SwGroup? _group;
  final _friendIds = <int>{};
  bool _saving = false;
  String? _error;

  int? get _amountMinor => parseMinor(_amount.text);

  int get _peopleCount => switch (_splitWith) {
        _SplitWith.group => _group?.members.length ?? 0,
        _SplitWith.friends => _friendIds.isEmpty ? 0 : _friendIds.length + 1,
      };

  bool get _canSave =>
      !_saving &&
      _amountMinor != null &&
      _description.text.trim().isNotEmpty &&
      _peopleCount > 1;

  Future<void> _save() async {
    final app = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_splitWith == _SplitWith.group) {
        await app.splitWithGroup(
          group: _group!,
          amountMinor: _amountMinor!,
          description: _description.text.trim(),
          from: widget.payment,
        );
      } else {
        await app.splitWithFriends(
          people: app.friends.where((f) => _friendIds.contains(f.id)).toList(),
          amountMinor: _amountMinor!,
          description: _description.text.trim(),
          from: widget.payment,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final amount = _amountMinor;
    final symbol = formatMoney(0, app.currency).replaceAll(RegExp(r'[\d.,\s]'), '');
    const noBorder = OutlineInputBorder(borderSide: BorderSide.none);

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Split expense'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xl),
                  children: [
                    Text(
                      'Amount',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                    // Symbol + amount centred together, sized to the digits.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          symbol,
                          style: text.displaySmall?.copyWith(
                            fontSize: 44,
                            color: _amount.text.isEmpty ? t.trayDeep : t.ink,
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 32, maxWidth: 260),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _amount,
                              autofocus: widget.payment == null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              style: text.displaySmall?.copyWith(fontSize: 44),
                              decoration: InputDecoration(
                                filled: false,
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
                                hintText: '0',
                                hintStyle: text.displaySmall
                                    ?.copyWith(fontSize: 44, color: t.trayDeep),
                                border: noBorder,
                                enabledBorder: noBorder,
                                focusedBorder: noBorder,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: 'What was it for?'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Space.xxl),
                    PillSegmented<_SplitWith>(
                      options: const {_SplitWith.group: 'Group', _SplitWith.friends: 'Friends'},
                      value: _splitWith,
                      onChanged: (v) => setState(() => _splitWith = v),
                    ),
                    const SizedBox(height: Space.lg),
                    if (app.loading)
                      const Padding(
                        padding: EdgeInsets.all(Space.xxl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_splitWith == _SplitWith.group)
                      for (final group in app.groups) ...[
                        _GroupOption(
                          group: group,
                          selected: _group?.id == group.id,
                          onTap: () => setState(() => _group = group),
                        ),
                        const SizedBox(height: Space.md),
                      ]
                    else
                      for (final friend in app.friends) ...[
                        _FriendOption(
                          friend: friend,
                          selected: _friendIds.contains(friend.id),
                          onTap: () => setState(() => _friendIds.contains(friend.id)
                              ? _friendIds.remove(friend.id)
                              : _friendIds.add(friend.id)),
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Text(
                          _error!,
                          style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              _Footer(
                summary: amount != null && _peopleCount > 1
                    ? '${formatMoney(amount ~/ _peopleCount, app.currency)} each · $_peopleCount people'
                    : null,
                label: amount == null ? 'Split' : 'Split ${formatMoney(amount, app.currency)}',
                saving: _saving,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupOption extends StatelessWidget {
  const _GroupOption({required this.group, required this.selected, required this.onTap});

  final SwGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      child: SurfaceCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${group.members.length} people',
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
            AvatarStack(group.members.map((m) => m.name).toList()),
          ],
        ),
      ),
    );
  }
}

class _FriendOption extends StatelessWidget {
  const _FriendOption({required this.friend, required this.selected, required this.onTap});

  final SwUser friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      child: SurfaceCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: [
            Avatar(friend.name),
            const SizedBox(width: Space.md),
            Expanded(child: Text(friend.name, style: Theme.of(context).textTheme.titleMedium)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.ink : Colors.transparent,
                border: Border.all(color: selected ? t.ink : t.trayDeep, width: 2),
              ),
              child: selected ? Icon(Icons.check, size: 16, color: t.onInk) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.summary,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  final String? summary;
  final String label;
  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: summary == null
                ? const SizedBox(height: 0)
                : Padding(
                    key: ValueKey(summary),
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(summary!, style: text.bodyMedium?.copyWith(color: t.muted)),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              child: saving
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.onInk),
                    )
                  : Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
