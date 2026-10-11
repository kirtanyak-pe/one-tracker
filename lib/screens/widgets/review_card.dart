import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../engine/enrich.dart';
import '../../model/category.dart';
import '../../model/transaction.dart';
import '../../money.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';

/// The one orange moment: big payments (above the threshold in Settings),
/// one at a time. Everything else counts as an expense without asking.
class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key, required this.queue, required this.currency});

  final List<Enriched> queue;
  final String currency;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  static const _badge = 56.0;
  Category? _picked;
  bool _busy = false;

  Enriched get _current => widget.queue.first;

  @override
  void didUpdateWidget(ReviewCard old) {
    super.didUpdateWidget(old);
    if (old.queue.firstOrNull?.txn.id != widget.queue.firstOrNull?.txn.id) _picked = null;
  }

  Future<void> _run(Future<void> Function(AppController app) action) async {
    setState(() => _busy = true);
    try {
      await action(AppScope.of(context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(AppController app) async {
    final e = _current;
    final picked = _picked;
    if (picked == null || picked == e.category) {
      await app.markReviewed(e.txn);
      return;
    }
    await app.setCategory(e.txn, picked);
    // Teach it: future payments to this payee get the same category.
    final updated = app.find(e.txn.id);
    if (updated != null) await app.rememberFor(updated);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final e = _current;
    final category = _picked ?? e.category;
    final options = [
      category,
      ...[Category.people, Category.bills, Category.food, Category.shopping, Category.groceries,
          Category.transport, Category.health, Category.other]
          .where((c) => c != category),
    ];

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
              Positioned(
                top: Space.lg,
                left: Space.xl,
                child: Text(
                  widget.queue.length == 1 ? '1 big payment' : '${widget.queue.length} big payments',
                  style: text.bodySmall?.copyWith(color: t.onAccent, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, _badge / 2 + Space.lg, Space.xl, Space.xl),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(e.txn.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMoney(e.txn.amountMinor, widget.currency),
                        style: text.headlineMedium?.copyWith(
                          color: t.onAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'to ${e.payee} · ${dayLabel(e.txn.at)}\nCount it as an expense?',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: text.bodyLarge?.copyWith(color: t.onAccent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Space.xl),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                          itemBuilder: (_, i) => _OnAccentPill(
                            category: options[i],
                            selected: options[i] == category,
                            onTap: _busy ? null : () => setState(() => _picked = options[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      SizedBox(
                        height: 20,
                        child: _picked != null && _picked != e.category
                            ? Text(
                                "I'll file ${e.payee} under ${_picked!.label} from now on",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: t.onAccent),
                              )
                            : null,
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: OnAccentButtonStyle.ghost(t),
                              onPressed: _busy ? null : () => _run((app) => app.setKind(e.txn, TxnKind.notExpense)),
                              child: const Text('Not expense'),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: FilledButton(
                              style: OnAccentButtonStyle.solid(t),
                              onPressed: _busy ? null : () => _run(_confirm),
                              child: const Text('Expense'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
            child: Icon(Icons.question_mark_rounded, color: t.accent, size: 22),
          ),
        ),
      ],
    );
  }
}

class _OnAccentPill extends StatelessWidget {
  const _OnAccentPill({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const ink = Color(0xFF111111);
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
                Icon(category.icon, size: 18, color: selected ? ink : t.onAccent),
                const SizedBox(width: Space.xs + 2),
                Text(
                  category.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? ink : t.onAccent,
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
