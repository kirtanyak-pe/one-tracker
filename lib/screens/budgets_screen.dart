import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../engine/summary.dart';
import '../model/category.dart';
import '../money.dart';
import '../ui/motion.dart';

import 'package:onyx/onyx.dart';

/// Monthly limits. Crossing 80% and 100% sends a notification.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final now = DateTime.now();
    // Budgets are about this month, whichever month Home is showing.
    final current = summarize(app.ledger, DateTime(now.year, now.month));
    final spentByCat = {for (final c in current.byCategory) c.category: c.amountMinor};
    final b = app.budgets;

    return OScreen(
      title: 'Budgets',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.xxxl),
        children: [
          Text(
            app.isAndroid
                ? "I'll notify you at 80% and when a budget runs out."
                : 'Set a monthly limit, and limits per category.',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const OSectionHeader('Every month', top: OSpace.xl),
          _BudgetRow(
            icon: LucideIcons.calendarDays,
            label: 'Total spending',
            spent: current.spentMinor,
            limit: b.monthlyMinor,
            onChanged: (v) => app.setBudgets(b.withMonthly(v)),
          ),
          const OSectionHeader('By category'),
          OCard(
            padding: const EdgeInsets.symmetric(vertical: OSpace.xs),
            child: Column(
              children: [
                for (final (i, c) in Category.spending.indexed) ...[
                  if (i > 0) const ODivider(indent: 68),
                  _BudgetRow(
                    icon: c.icon,
                    label: c.label,
                    spent: spentByCat[c] ?? 0,
                    limit: b.byCategory[c],
                    flat: true,
                    onChanged: (v) => app.setBudgets(b.withCategory(c, v)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatefulWidget {
  const _BudgetRow({
    required this.icon,
    required this.label,
    required this.spent,
    required this.limit,
    required this.onChanged,
    this.flat = false,
  });

  final IconData icon;
  final String label;
  final int spent;
  final int? limit;
  final ValueChanged<int?> onChanged;

  /// Inside a shared card rather than its own.
  final bool flat;

  @override
  State<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends State<_BudgetRow> {
  late final _field = TextEditingController(text: widget.limit == null ? '' : (widget.limit! ~/ 100).toString());

  void _commit() {
    final rupees = int.tryParse(_field.text.replaceAll(',', ''));
    widget.onChanged(rupees == null || rupees <= 0 ? null : rupees * 100);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final limit = widget.limit;
    final use = limit == null ? null : widget.spent / limit;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle),
                child: Icon(widget.icon, size: 20, color: t.ink),
              ),
              const SizedBox(width: OSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: text.body),
                    Text(
                      '${formatMoney(widget.spent, appCurrency, round: true)} spent',
                      style: text.small.copyWith(color: t.inkSoft),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                child: Focus(
                  onFocusChange: (f) => f ? null : _commit(),
                  child: OField(
                    controller: _field,
                    textAlign: TextAlign.end,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: text.body.semibold.tabular,
                    placeholder: 'No limit',
                    prefixText: '₹ ',
                    onSubmitted: (_) => _commit(),
                  ),
                ),
              ),
            ],
          ),
          if (use != null) ...[
            const SizedBox(height: OSpace.md),
            AnimatedMeter(
              value: use,
              background: t.raised,
              color: use >= 1
                  ? t.negative
                  : use >= 0.8
                  ? t.warning
                  : t.ink,
            ),
          ],
        ],
      ),
    );
    return widget.flat ? row : OCard(padding: EdgeInsets.zero, child: row);
  }
}
