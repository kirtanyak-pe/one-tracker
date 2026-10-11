import 'package:flutter/material.dart';

import '../detection/detected_payment.dart';
import '../money.dart';
import '../splitwise/models.dart';

/// "₹450 at Swiggy — split it?" card. Shown inside the floating bubble on
/// Android, and as a bottom sheet where overlays aren't available.
class QuickSplitCard extends StatefulWidget {
  const QuickSplitCard({
    super.key,
    required this.payment,
    required this.groups,
    required this.currency,
    required this.onSplit,
    required this.onLater,
    this.onMoreOptions,
  });

  final DetectedPayment payment;
  final List<SwGroup> groups;
  final String currency;
  final Future<void> Function(SwGroup group) onSplit;
  final VoidCallback onLater;

  /// Opens the full split screen (friends, custom amount). Hidden if null.
  final VoidCallback? onMoreOptions;

  @override
  State<QuickSplitCard> createState() => _QuickSplitCardState();
}

class _QuickSplitCardState extends State<QuickSplitCard> {
  SwGroup? _selected;
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _split() async {
    final group = _selected;
    if (group == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSplit(group);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = formatMoney(widget.payment.amountMinor, widget.currency);
    final merchant = widget.payment.merchant;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
        child: _done ? _buildDone(theme, amount) : _buildPrompt(theme, amount, merchant),
      ),
    );
  }

  Widget _buildDone(ThemeData theme, String amount) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$amount split with ${_selected!.name}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onLater,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _buildPrompt(ThemeData theme, String amount, String? merchant) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.call_split, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant == null ? 'You paid $amount' : '$amount at $merchant',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Split it on Splitwise?',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Not now',
                onPressed: widget.onLater,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'No Splitwise groups yet — open Auto Split to connect your account.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 12),
                itemCount: widget.groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final group = widget.groups[i];
                  return ChoiceChip(
                    label: Text(group.name),
                    selected: _selected?.id == group.id,
                    onSelected: _busy ? null : (_) => setState(() => _selected = group),
                  );
                },
              ),
            ),
          if (_selected != null) ...[
            const SizedBox(height: 4),
            Text(
              '${formatMoney(widget.payment.amountMinor ~/ _selected!.members.length, widget.currency)}'
              ' each · ${_selected!.members.length} people',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                if (widget.onMoreOptions != null)
                  TextButton(onPressed: widget.onMoreOptions, child: const Text('More options')),
                const Spacer(),
                FilledButton(
                  onPressed: _selected == null || _busy ? null : _split,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Split equally'),
                ),
              ],
            ),
          ),
        ],
      );
}
