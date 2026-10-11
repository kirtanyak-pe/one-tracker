import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../engine/summary.dart';
import '../model/category.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';

/// Monthly limits. Crossing 80% and 100% sends a notification.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    // Budgets are about this month, whichever month Home is showing.
    final current = summarize(app.ledger, DateTime(now.year, now.month));
    final spentByCat = {for (final c in current.byCategory) c.category: c.amountMinor};
    final b = app.budgets;

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Budgets'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
                  children: [
                    Text(
                      app.isAndroid
                          ? "I'll notify you at 80% and when a budget runs out."
                          : 'Set a monthly limit, and limits per category.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                    const SectionHeader('Every month', top: Space.xl),
                    _BudgetRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Total spending',
                      spent: current.spentMinor,
                      limit: b.monthlyMinor,
                      onChanged: (v) => app.setBudgets(b.withMonthly(v)),
                    ),
                    const SectionHeader('By category'),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Column(
                        children: [
                          for (final (i, c) in Category.spending.indexed) ...[
                            if (i > 0) Divider(height: 1, color: t.tray, indent: 68),
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
              ),
            ],
          ),
        ),
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
  late final _field = TextEditingController(
    text: widget.limit == null ? '' : (widget.limit! ~/ 100).toString(),
  );

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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final limit = widget.limit;
    final use = limit == null ? null : widget.spent / limit;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                child: Icon(widget.icon, size: 20, color: t.ink),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: text.bodyMedium),
                    Text(
                      '${formatMoney(widget.spent, appCurrency, round: true)} spent',
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                child: Focus(
                  onFocusChange: (f) => f ? null : _commit(),
                  child: TextField(
                    controller: _field,
                    textAlign: TextAlign.end,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'No limit',
                      prefixText: '₹ ',
                      isDense: true,
                      fillColor: t.tray,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 12),
                    ),
                    onSubmitted: (_) => _commit(),
                  ),
                ),
              ),
            ],
          ),
          if (use != null) ...[
            const SizedBox(height: Space.md),
            AnimatedMeter(
              value: use,
              background: t.tray,
              color: use >= 1 ? Theme.of(context).colorScheme.error : use >= 0.8 ? t.accent : t.ink,
            ),
          ],
        ],
      ),
    );
    return widget.flat ? row : SurfaceCard(padding: EdgeInsets.zero, child: row);
  }
}
