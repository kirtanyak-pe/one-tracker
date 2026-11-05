import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../money.dart';
import '../ui/motion.dart';

import 'package:onyx/onyx.dart';

import 'transactions_screen.dart';
import 'widgets/month_switcher.dart';

/// Spending by category for the selected month, with budgets where set.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final m = app.month;
    final budgets = app.budgets.byCategory;

    return OScreen(
      title: 'Where it went',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.xxxl),
        children: [
          const Center(child: MonthSwitcher()),
          const SizedBox(height: OSpace.xl),
          AnimatedMoney(m.spentMinor, round: true, textAlign: TextAlign.center, style: text.display.tabular),
          Text(
            '${m.spendCount} payment${m.spendCount == 1 ? '' : 's'} across ${m.byCategory.length} categories',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const SizedBox(height: OSpace.xl),
          if (m.byCategory.isEmpty)
            OInset(
              child: Text(
                'No spending this month yet.',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: t.inkSoft),
              ),
            )
          else
            OCard(
              padding: const EdgeInsets.symmetric(vertical: OSpace.sm),
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
                        onTap: () => pushScreen(context, TransactionsScreen.category(c.category)),
                      ),
                    ),
                ],
              ),
            ),
        ],
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
    final t = context.colors;
    final text = context.type;
    final over = budget != null && amount >= budget!;
    return OPressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.raised, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: t.ink),
            ),
            const SizedBox(width: OSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(label, style: text.body)),
                      Text(
                        [
                          formatMoney(amount, appCurrency, round: true),
                          if (budget != null) formatCompact(budget!),
                        ].join(' / '),
                        style: text.body.copyWith(fontWeight: FontWeight.w600).tabular,
                      ),
                    ],
                  ),
                  const SizedBox(height: OSpace.sm),
                  AnimatedMeter(
                    // Against its budget when there is one, else vs the top category.
                    value: budget != null ? amount / budget! : amount / top,
                    background: t.raised,
                    color: over ? t.negative : t.ink,
                  ),
                  const SizedBox(height: OSpace.xs),
                  Text(
                    '${(share * 100).round()}% · $count payment${count == 1 ? '' : 's'}'
                    '${over ? ' · over budget' : ''}',
                    style: text.small.copyWith(color: t.inkSoft),
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
