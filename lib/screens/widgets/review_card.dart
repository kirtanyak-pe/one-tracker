import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../engine/enrich.dart';
import '../../model/category.dart';
import '../../model/transaction.dart';
import '../../money.dart';
import '../../ui/format.dart';
import '../../ui/payee_logo.dart';

import 'package:onyx/onyx.dart';

import 'prompt_card_parts.dart';

/// Big payments (above the threshold in Settings), one at a time. Everything
/// else counts as an expense without asking. An ink card: who and how much, one question, category chips, two actions.
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
    final t = context.colors;
    final text = context.type;
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
        duration: OMotion.of(context, OMotion.base),
        // Next payment slides in from the right.
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: OMotion.standard)).animate(animation),
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
            const SizedBox(height: OSpace.lg),
            Text('Count it as an expense?', style: text.body.semibold.copyWith(color: t.onInk)),
            const SizedBox(height: OSpace.xs),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(width: OSpace.sm),
                itemBuilder: (_, i) => _CategoryChip(
                  category: options[i],
                  selected: options[i] == category,
                  onTap: _busy ? null : () => setState(() => _picked = options[i]),
                ),
              ),
            ),
            AnimatedSize(
              duration: OMotion.of(context, OMotion.fast),
              alignment: Alignment.topLeft,
              child: filing
                  ? Padding(
                      padding: const EdgeInsets.only(top: OSpace.xs),
                      child: Text(
                        "I'll file ${e.payee} under ${_picked!.label} from now on",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.small.copyWith(color: promptMuted(t)),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: OSpace.md),
            Row(
              children: [
                Expanded(
                  child: OButton(
                    label: 'Not expense',
                    variant: OButtonVariant.inverseSoft,
                    size: OButtonSize.lg,
                    expand: true,
                    onPressed: _busy ? null : () => _run((app) => app.setKind(e.txn, TxnKind.notExpense)),
                  ),
                ),
                const SizedBox(width: OSpace.sm),
                Expanded(
                  child: OButton(
                    label: 'Expense',
                    variant: OButtonVariant.inverse,
                    size: OButtonSize.lg,
                    expand: true,
                    onPressed: _busy ? null : () => _run(_confirm),
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

/// Category choice on the ink card: soft pill, canvas-filled when picked.
/// 48dp tall hit area around a 40dp pill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final fg = selected ? t.ink : t.onInk;
    return Semantics(
      selected: selected,
      button: true,
      label: category.label,
      excludeSemantics: true,
      child: OPressable(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: OMotion.of(context, OMotion.fast),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: OSpace.lg),
            decoration: ShapeDecoration(
              color: selected ? t.onInk : t.onInk.withValues(alpha: 0.14),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 18, color: fg),
                const SizedBox(width: OSpace.sm),
                Text(category.label, style: context.type.label.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
