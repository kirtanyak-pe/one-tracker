import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../engine/month_nudge.dart';
import '../../money.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
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
    final t = context.tokens;
    final n = nudge.items.length;
    final next = monthName(nudge.nextMonth);

    return PromptSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromptHeader(
            icon: Icons.event_repeat,
            title: 'Count in $next?',
            subtitle: '$n payment${n == 1 ? '' : 's'} on ${_days(nudge)}',
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: PromptButtons.secondary(t),
                  onPressed: () => app.dismissNudge(nudge),
                  child: const OneLineLabel('Not now'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                flex: 3,
                child: FilledButton(
                  style: PromptButtons.primary(t),
                  onPressed: () => showMonthNudgeSheet(context, nudge),
                  child: const OneLineLabel('Review'),
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
Future<void> showMonthNudgeSheet(BuildContext context, MonthNudge nudge) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NudgeSheet(nudge: nudge),
    );

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
    final messenger = ScaffoldMessenger.of(context);
    final ids = _picked.toList();
    final next = monthName(widget.nudge.nextMonth);
    Navigator.pop(context);
    await app.moveManyToNextMonth(ids);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(ids.length == 1 ? 'Counted in $next' : '${ids.length} payments counted in $next'),
        action: SnackBarAction(label: 'Undo', onPressed: () => app.moveManyBack(ids)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final nudge = widget.nudge;
    final next = monthName(nudge.nextMonth);
    final n = _picked.length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: t.trayDeep, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: Space.lg),
              Text('Count in $next', style: text.titleLarge),
              const SizedBox(height: Space.xs),
              Text(
                'Payments from ${_days(nudge)}. Pick the ones that belong to $next.',
                style: text.bodySmall?.copyWith(color: t.muted),
              ),
              const SizedBox(height: Space.md),
              Flexible(
                child: SingleChildScrollView(
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, e) in nudge.items.indexed) ...[
                          if (i > 0) Divider(height: 1, indent: Space.lg, endIndent: Space.lg, color: t.tray),
                          InkWell(
                            onTap: () => setState(
                              () => _picked.contains(e.txn.id) ? _picked.remove(e.txn.id) : _picked.add(e.txn.id),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 64),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.lg, Space.xs),
                                child: Row(
                                  children: [
                                    IgnorePointer(
                                      child: Checkbox(
                                        value: _picked.contains(e.txn.id),
                                        onChanged: (_) {},
                                        activeColor: t.accentDeep,
                                        checkColor: t.onAccent,
                                        side: BorderSide(color: t.muted, width: 2),
                                      ),
                                    ),
                                    const SizedBox(width: Space.xs),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                                          Text(dayLabel(e.txn.at), style: text.bodySmall?.copyWith(color: t.muted)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Text(
                                      formatMoney(e.txn.amountMinor, appCurrency),
                                      maxLines: 1,
                                      style: text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: PromptButtons.primary(t),
                  onPressed: n == 0 ? null : _confirm,
                  child: OneLineLabel(n == 0 ? 'Count in $next' : 'Count $n in $next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
