import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../detection/detected_payment.dart';
import '../money.dart';
import '../splitwise/models.dart';

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
    final theme = Theme.of(context);
    final amount = _amountMinor;
    final symbol = formatMoney(0, app.currency).replaceAll(RegExp(r'[\d.,\s]'), '');

    return Scaffold(
      appBar: AppBar(title: const Text('Split expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What was it for?',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SegmentedButton<_SplitWith>(
            segments: const [
              ButtonSegment(value: _SplitWith.group, label: Text('Group'), icon: Icon(Icons.groups_outlined)),
              ButtonSegment(value: _SplitWith.friends, label: Text('Friends'), icon: Icon(Icons.person_outline)),
            ],
            selected: {_splitWith},
            onSelectionChanged: (s) => setState(() => _splitWith = s.first),
          ),
          const SizedBox(height: 8),
          if (app.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_splitWith == _SplitWith.group)
            RadioGroup<int>(
              groupValue: _group?.id,
              onChanged: (id) =>
                  setState(() => _group = app.groups.firstWhere((g) => g.id == id)),
              child: Column(
                children: [
                  for (final group in app.groups)
                    RadioListTile<int>(
                      value: group.id,
                      contentPadding: EdgeInsets.zero,
                      title: Text(group.name),
                      subtitle: Text(group.members.map((m) => m.firstName).join(', ')),
                    ),
                ],
              ),
            )
          else
            for (final friend in app.friends)
              CheckboxListTile(
                value: _friendIds.contains(friend.id),
                contentPadding: EdgeInsets.zero,
                title: Text(friend.name),
                onChanged: (on) => setState(
                  () => on! ? _friendIds.add(friend.id) : _friendIds.remove(friend.id),
                ),
              ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (amount != null && _peopleCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${formatMoney(amount ~/ _peopleCount, app.currency)} each'
                    ' · $_peopleCount people · you paid',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(amount == null
                          ? 'Split'
                          : 'Split ${formatMoney(amount, app.currency)}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
