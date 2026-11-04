import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../engine/enrich.dart';
import '../../model/category.dart';
import '../../model/transaction.dart';
import '../../money.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/motion.dart';
import '../../ui/payee_logo.dart';
import '../../ui/tokens.dart';
import 'prompt_card_parts.dart';

/// Big payments (above the threshold in Settings), one at a time. Everything
/// else counts as an expense without asking. A white card like the rest of
/// the app: who and how much, one question, category chips, two actions.
class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key, required this.queue, required this.currency});

  final List<Enriched> queue;
  final String currency;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
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
      ...[
        Category.people,
        Category.bills,
        Category.food,
        Category.shopping,
        Category.groceries,
        Category.transport,
        Category.health,
        Category.other,
      ].where((c) => c != category),
    ];
    final count = widget.queue.length;
    final filing = _picked != null && _picked != e.category;

    return PromptSurface(
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        // Next payment slides in from the right.
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Motion.enter)).animate(animation),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(e.txn.id),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PromptHeader(
              icon: category.icon,
              leading: PayeeAvatar(e, size: 44),
              title: e.payee,
              subtitle: count == 1
                  ? '${dayLabel(e.txn.at)} · Big payment'
                  : '${dayLabel(e.txn.at)} · Big payment, 1 of $count',
              amount: formatMoney(e.txn.amountMinor, widget.currency),
            ),
            const SizedBox(height: Space.lg),
            Text('Count it as an expense?', style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Space.xs),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, i) => _CategoryChip(
                  category: options[i],
                  selected: options[i] == category,
                  onTap: _busy ? null : () => setState(() => _picked = options[i]),
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.fast),
              alignment: Alignment.topLeft,
              child: filing
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Text(
                        "I'll file ${e.payee} under ${_picked!.label} from now on",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: t.muted),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: PromptButtons.secondary(t),
                    onPressed: _busy ? null : () => _run((app) => app.setKind(e.txn, TxnKind.notExpense)),
                    child: const OneLineLabel('Not expense'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton(
                    style: PromptButtons.primary(t),
                    onPressed: _busy ? null : () => _run(_confirm),
                    child: const OneLineLabel('Expense'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Category choice: tray pill, ink-filled when picked. 48dp tall hit area
/// around a 40dp pill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.onInk : t.ink;
    return Semantics(
      selected: selected,
      button: true,
      label: category.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Center(
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            decoration: ShapeDecoration(color: selected ? t.ink : t.tray, shape: const StadiumBorder()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 18, color: fg),
                const SizedBox(width: Space.sm),
                Text(category.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
