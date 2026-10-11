import 'package:flutter/material.dart';

import '../detection/detected_payment.dart';
import '../money.dart';
import '../splitwise/models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// "₹450 at Swiggy — split it?" — the one orange moment. Shown inside the
/// floating bubble on Android, and as a bottom sheet in the app.
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

  static const _badge = 56.0;

  Future<void> _split() async {
    final group = _selected;
    if (group == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSplit(group);
      if (!mounted) return;
      setState(() => _done = true);
      // Let the confirmation land, then get out of the way.
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) widget.onLater();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final amount = formatMoney(widget.payment.amountMinor, widget.currency);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: _badge / 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            // Reference-orange light in the top-right corner.
            gradient: RadialGradient(
              center: const Alignment(1, -1),
              radius: 1.3,
              colors: [t.accent, t.accentDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: t.accentDeep.withValues(alpha: 0.30),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(top: 0, right: 0, child: ConcentricArcs()),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.xl, _badge / 2 + Space.lg, Space.xl, Space.xl),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _done ? _buildDone(t, amount) : _buildPrompt(t, amount),
                ),
              ),
              Positioned(
                top: Space.xs,
                right: Space.xs,
                child: IconButton(
                  tooltip: _done ? 'Close' : 'Not now',
                  onPressed: widget.onLater,
                  icon: Icon(Icons.close, color: t.onAccent),
                ),
              ),
            ],
          ),
        ),
        // Dark badge sitting on the top edge, as on the reference card.
        Container(
          width: _badge,
          height: _badge,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: t.canvas, shape: BoxShape.circle),
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF151515), shape: BoxShape.circle),
            child: Icon(
              _done ? Icons.check : Icons.call_split,
              color: _done ? t.success : t.accent,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(AppTokens t, String amount) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Split!',
            style: text.headlineMedium?.copyWith(color: t.onAccent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Space.xs),
          Text(
            '$amount with ${_selected!.name} is on Splitwise',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: t.onAccent),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    );
  }

  Widget _buildPrompt(AppTokens t, String amount) {
    final text = Theme.of(context).textTheme;
    final merchant = widget.payment.merchant;
    final selected = _selected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount,
          style: text.headlineMedium?.copyWith(
            color: t.onAccent,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          merchant == null ? 'Split this payment?' : 'at $merchant · split it?',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: t.onAccent, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Space.xl),
        if (widget.groups.isEmpty)
          Text(
            'Connect Splitwise in Auto Split to see your groups.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: t.onAccent),
          )
        else
          SizedBox(
            height: 44,
            // Bleeds into the card padding, clipped by the card edge.
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: widget.groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (_, i) => _GroupPill(
                group: widget.groups[i],
                selected: selected?.id == widget.groups[i].id,
                onTap: _busy ? null : () => setState(() => _selected = widget.groups[i]),
              ),
            ),
          ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 20,
          child: selected == null
              ? null
              : Text(
                  '${formatMoney(widget.payment.amountMinor ~/ selected.members.length, widget.currency)}'
                  ' each · ${selected.members.length} people',
                  style: text.bodySmall?.copyWith(color: t.onAccent),
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(Radii.input),
            ),
            child: Text(_error!, style: text.bodySmall?.copyWith(color: const Color(0xFFB3261E))),
          ),
        ],
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: OnAccentButtonStyle.ghost(t),
                onPressed: widget.onMoreOptions ?? widget.onLater,
                child: Text(widget.onMoreOptions == null ? 'Later' : 'More options'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: FilledButton(
                style: OnAccentButtonStyle.solid(t),
                onPressed: selected == null || _busy ? null : _split,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF111111)),
                      )
                    : const Text('Split equally'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupPill extends StatelessWidget {
  const _GroupPill({required this.group, required this.selected, required this.onTap});

  final SwGroup group;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: selected ? 1 : 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check, size: 18, color: Color(0xFF111111)),
                  const SizedBox(width: Space.xs),
                ],
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? const Color(0xFF111111) : t.onAccent,
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
