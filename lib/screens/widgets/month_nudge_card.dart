import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../engine/month_nudge.dart';
import '../../money.dart';
import '../../ui/format.dart';

import 'package:onyx/onyx.dart';

import 'prompt_card_parts.dart';

String _short(DateTime month) => monthName(month).substring(0, 3);

String _days(MonthNudge n) => '${n.firstDay}–${n.lastDay} ${_short(n.paidMonth)}';

/// One quiet card in the first days of a month: payments from the last days
/// of the previous one may belong here (salary lands late, bills go out the
/// same day). "Review" opens a sheet to pick them; "Not now" hides it.
class MonthNudgeCard extends StatelessWidget {
  const MonthNudgeCard({super.key, required this.nudge});

  final MonthNudge nudge;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final n = nudge.items.length;
    final next = monthName(nudge.nextMonth);

    return PromptSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromptHeader(
            icon: LucideIcons.calendarSync,
            title: 'Count in $next?',
            subtitle: '$n payment${n == 1 ? '' : 's'} on ${_days(nudge)}',
          ),
          const SizedBox(height: OSpace.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OButton(
                  label: 'Not now',
                  variant: OButtonVariant.inverseSoft,
                  size: OButtonSize.lg,
                  expand: true,
                  onPressed: () => app.dismissNudge(nudge),
                ),
              ),
              const SizedBox(width: OSpace.sm),
              Expanded(
                flex: 3,
                child: OButton(
                  label: 'Review',
                  variant: OButtonVariant.inverse,
                  size: OButtonSize.lg,
                  expand: true,
                  onPressed: () => showMonthNudgeSheet(context, nudge),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pick which of the payments to count in the next month.
Future<void> showMonthNudgeSheet(BuildContext context, MonthNudge nudge) =>
    showOSheet<void>(context, builder: (_) => _NudgeSheet(nudge: nudge));

class _NudgeSheet extends StatefulWidget {
  const _NudgeSheet({required this.nudge});

  final MonthNudge nudge;

  @override
  State<_NudgeSheet> createState() => _NudgeSheetState();
}

class _NudgeSheetState extends State<_NudgeSheet> {
  late final Set<String> _picked = {for (final e in widget.nudge.items) e.txn.id};

  Future<void> _confirm() async {
    final app = AppScope.of(context);
    final ids = _picked.toList();
    final next = monthName(widget.nudge.nextMonth);
    // The sheet's own context is gone after pop; toast from the root navigator.
    final root = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    await app.moveManyToNextMonth(ids);
    if (!root.mounted) return;
    OToast.show(
      root,
      ids.length == 1 ? 'Counted in $next' : '${ids.length} payments counted in $next',
      actionLabel: 'Undo',
      onAction: () => app.moveManyBack(ids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final nudge = widget.nudge;
    final next = monthName(nudge.nextMonth);
    final n = _picked.length;

    return OSheetBody(
      title: 'Count in $next',
      subtitle: 'Payments from ${_days(nudge)}. Pick the ones that belong to $next.',
      actions: [
        OButton(
          label: n == 0 ? 'Count in $next' : 'Count $n in $next',
          size: OButtonSize.lg,
          expand: true,
          onPressed: n == 0 ? null : _confirm,
        ),
      ],
      child: OCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, e) in nudge.items.indexed) ...[
              if (i > 0) const ODivider(indent: OSpace.lg, endIndent: OSpace.lg),
              OPressable(
                onTap: () =>
                    setState(() => _picked.contains(e.txn.id) ? _picked.remove(e.txn.id) : _picked.add(e.txn.id)),
                pressedScale: 0.99,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.xs),
                    child: Row(
                      children: [
                        IgnorePointer(
                          child: OCheckbox(value: _picked.contains(e.txn.id), onChanged: (_) {}),
                        ),
                        const SizedBox(width: OSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.title3),
                              Text(dayLabel(e.txn.at), style: text.small.copyWith(color: t.inkSoft)),
                            ],
                          ),
                        ),
                        const SizedBox(width: OSpace.sm),
                        Text(formatMoney(e.txn.amountMinor, appCurrency), maxLines: 1, style: text.title3.tabular),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
