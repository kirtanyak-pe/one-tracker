import 'package:flutter/material.dart';

import '../money.dart';
import '../splitwise/models.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'split_models.dart';

/// "₹450 at Swiggy → Flatmates" — the orange split card. Used floating over
/// other apps right after a payment, and as a sheet inside the app.
class SplitCard extends StatefulWidget {
  const SplitCard({
    super.key,
    required this.prompt,
    required this.groups,
    required this.friends,
    required this.defaultTarget,
    required this.onSplit,
    required this.onDismiss,
    this.demo = false,
    this.onExpandedChanged,
  });

  final SplitPrompt prompt;
  final List<SwGroup> groups;
  final List<SwUser> friends;
  final SplitTarget? defaultTarget;
  final bool demo;

  /// Sends it to Splitwise; [makeDefault] saves the target for next time.
  final Future<void> Function(SplitTarget target, bool makeDefault) onSplit;
  final VoidCallback onDismiss;

  /// The picker opened/closed — the floating window resizes to fit.
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<SplitCard> createState() => _SplitCardState();
}

class _SplitCardState extends State<SplitCard> {
  static const _badge = 56.0;
  static const _white = Colors.white;
  static const _ink = Color(0xFF111111);

  late SplitTarget? _target = widget.defaultTarget;
  late bool _picking = widget.defaultTarget == null;
  final _friendIds = <int>{};
  bool _makeDefault = false;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_picking) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpandedChanged?.call(true));
  }

  void _setPicking(bool on) {
    setState(() => _picking = on);
    widget.onExpandedChanged?.call(on);
  }

  void _pickGroup(SwGroup g) => setState(() {
        _friendIds.clear();
        _target = SplitTarget.group(g);
      });

  void _toggleFriend(SwUser f) => setState(() {
        _friendIds.contains(f.id) ? _friendIds.remove(f.id) : _friendIds.add(f.id);
        final picked = widget.friends.where((x) => _friendIds.contains(x.id)).toList();
        _target = picked.isEmpty ? null : SplitTarget.friends(picked);
      });

  Future<void> _split() async {
    final target = _target;
    if (target == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSplit(target, _makeDefault || widget.defaultTarget == null);
      if (!mounted) return;
      setState(() => _done = true);
      widget.onExpandedChanged?.call(false);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) widget.onDismiss();
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: _badge / 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            gradient: RadialGradient(
              center: const Alignment(1, -1),
              radius: 1.3,
              colors: [t.accent, t.accentDeep],
            ),
            boxShadow: [
              BoxShadow(color: t.accentDeep.withValues(alpha: 0.30), blurRadius: 28, offset: const Offset(0, 12)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(top: 0, right: 0, child: ConcentricArcs()),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, _badge / 2 + Space.md, Space.xl, Space.xl),
                child: AnimatedSize(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.enter,
                  alignment: Alignment.topCenter,
                  child: _done ? _buildDone(t) : _buildPrompt(t),
                ),
              ),
              Positioned(
                top: Space.xs,
                right: Space.xs,
                child: IconButton(
                  tooltip: 'Not now',
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close, color: _white),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: _badge,
          height: _badge,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: t.canvas, shape: BoxShape.circle),
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF151515), shape: BoxShape.circle),
            child: Icon(_done ? Icons.check : Icons.call_split, color: _done ? t.success : t.accent, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(AppTokens t) {
    final text = Theme.of(context).textTheme;
    final target = _target!;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Split!', style: text.headlineMedium?.copyWith(color: _white, fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.xs),
          Text(
            widget.demo
                ? 'Demo mode, nothing was sent. Connect Splitwise in the Split tab.'
                : '${formatMoney(target.shareOf(widget.prompt.amountMinor), appCurrency)} each with ${target.label}, on Splitwise',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: _white),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt(AppTokens t) {
    final text = Theme.of(context).textTheme;
    final p = widget.prompt;
    final target = _target;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          formatMoney(p.amountMinor, appCurrency),
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(color: _white, fontSize: 32, fontWeight: FontWeight.w700),
        ),
        Text(
          'at ${p.payee} · ${friendlyTime(p.at)}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(color: _white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Space.lg),
        if (!_picking && target != null)
          _TargetPill(
            target: target,
            share: formatMoney(target.shareOf(p.amountMinor), appCurrency),
            onChange: () => _setPicking(true),
          )
        else
          _Picker(
            groups: widget.groups,
            friends: widget.friends,
            target: target,
            friendIds: _friendIds,
            onGroup: _pickGroup,
            onFriend: _toggleFriend,
          ),
        if (_picking) ...[
          // Fixed slots: choosing must never move the chips under your finger.
          const SizedBox(height: Space.sm),
          SizedBox(
            height: 20,
            child: Text(
              target == null
                  ? 'Pick a group or friends'
                  : '${formatMoney(target.shareOf(p.amountMinor), appCurrency)} each, ${target.people} people',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: _white),
            ),
          ),
          if (widget.defaultTarget != null)
            SizedBox(
              height: 44,
              child: target != null && !target.sameAs(widget.defaultTarget)
                  ? _DefaultToggle(value: _makeDefault, onChanged: (v) => setState(() => _makeDefault = v))
                  : null,
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(Radii.input)),
            child: Text(_error!, style: text.bodySmall?.copyWith(color: const Color(0xFFB3261E))),
          ),
        ],
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: OnAccentButtonStyle.ghost(t),
                onPressed: _busy ? null : widget.onDismiss,
                child: const OneLineLabel('Not now'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: FilledButton(
                style: OnAccentButtonStyle.solid(t),
                onPressed: target == null || _busy ? null : _split,
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
                    : const OneLineLabel('Split'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetPill extends StatelessWidget {
  const _TargetPill({required this.target, required this.share, required this.onChange});

  final SplitTarget target;
  final String share;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              target.kind == TargetKind.group ? Icons.groups_outlined : Icons.people_outline,
              size: 20,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
                Text('$share each, ${target.people} people', style: text.bodySmall?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.groups,
    required this.friends,
    required this.target,
    required this.friendIds,
    required this.onGroup,
    required this.onFriend,
  });

  final List<SwGroup> groups;
  final List<SwUser> friends;
  final SplitTarget? target;
  final Set<int> friendIds;
  final ValueChanged<SwGroup> onGroup;
  final ValueChanged<SwUser> onFriend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    if (groups.isEmpty && friends.isEmpty) {
      return Text(
        'No Splitwise groups or friends yet. Connect Splitwise in the Split tab.',
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(color: Colors.white),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groups.isNotEmpty) ...[
          Text('Group', style: label),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final g in groups)
                OnAccentPill(
                  label: g.name,
                  selected: target?.kind == TargetKind.group && target?.groupId == g.id,
                  onTap: () => onGroup(g),
                ),
            ],
          ),
        ],
        if (friends.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text('Or friends', style: label),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final f in friends)
                OnAccentPill(label: f.name, selected: friendIds.contains(f.id), onTap: () => onFriend(f)),
            ],
          ),
        ],
      ],
    );
  }
}

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton.icon(
          onPressed: () => onChanged(!value),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: Icon(value ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
          label: const Text('Make this my default'),
        ),
      );
}

/// White-on-orange selectable pill (shared with the review card's style).
class OnAccentPill extends StatelessWidget {
  const OnAccentPill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111111);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: selected ? 1 : 0.4))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check, size: 16, color: ink),
                    const SizedBox(width: Space.xs),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: Space.xs),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? ink : Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
