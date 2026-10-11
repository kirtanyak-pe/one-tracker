import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'transactions_screen.dart';
import 'widgets/month_switcher.dart';

/// Spending by category for the selected month, with budgets where set.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = app.month;
    final budgets = app.budgets.byCategory;

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Where it went'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
                  children: [
                    const Center(child: MonthSwitcher()),
                    const SizedBox(height: Space.xl),
                    AnimatedMoney(
                      m.spentMinor,
                      round: true,
                      textAlign: TextAlign.center,
                      style: text.displaySmall,
                    ),
                    Text(
                      '${m.spendCount} payment${m.spendCount == 1 ? '' : 's'} across ${m.byCategory.length} categories',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: Space.xl),
                    if (m.byCategory.isEmpty)
                      Tray(
                        child: Text(
                          'No spending this month yet.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: t.muted),
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Column(
                          children: [
                            for (final (i, c) in m.byCategory.indexed)
                              FadeSlideIn(
                                index: i,
                                child: _CategoryRow(
                                highlight: i == 0,
                                icon: c.category.icon,
                                label: c.category.label,
                                amount: c.amountMinor,
                                count: c.count,
                                share: m.spentMinor == 0 ? 0 : c.amountMinor / m.spentMinor,
                                top: m.byCategory.first.amountMinor,
                                budget: budgets[c.category],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TransactionsScreen.category(c.category)),
                                ),
                              ),
                              ),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.highlight,
    required this.icon,
    required this.label,
    required this.amount,
    required this.count,
    required this.share,
    required this.top,
    required this.budget,
    required this.onTap,
  });

  final bool highlight;
  final IconData icon;
  final String label;
  final int amount;
  final int count;
  final double share;
  final int top;
  final int? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final over = budget != null && amount >= budget!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: t.ink),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(label, style: text.bodyMedium)),
                      Text(
                        [
                          formatMoney(amount, appCurrency, round: true),
                          if (budget != null) formatCompact(budget!),
                        ].join(' / '),
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  AnimatedMeter(
                    // Against its budget when there is one, else vs the top category.
                    value: budget != null ? amount / budget! : amount / top,
                    background: t.tray,
                    color: over ? Theme.of(context).colorScheme.error : highlight ? t.accent : t.ink,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${(share * 100).round()}% · $count payment${count == 1 ? '' : 's'}'
                    '${over ? ' · over budget' : ''}',
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
