import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../engine/insights.dart';
import '../engine/recurring.dart';
import '../money.dart';
import '../ui/bar_chart.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'home_screen.dart' show push;
import 'shell.dart';
import 'transactions_screen.dart';
import 'widgets/month_switcher.dart';
import 'widgets/txn_list.dart';

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final i = app.insights;
    final empty = i.month.spendCount == 0;

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, navClearance),
          children: staggered([
            Text('Insights', style: text.headlineMedium),
            const SizedBox(height: Space.lg),
            const Center(child: MonthSwitcher()),
            if (empty) ...[
              const SizedBox(height: Space.xxl),
              Tray(
                child: Text(
                  'No spending in ${monthName(i.month.month)} yet.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: t.muted),
                ),
              ),
            ] else ...[
              const SizedBox(height: Space.xl),
              _Pace(insights: i, current: app.isCurrentMonth),
              const SectionHeader('Day by day'),
              SurfaceCard(
                child: BarChart(
                  values: i.daily,
                  highlight: app.isCurrentMonth ? i.dayOfMonth - 1 : null,
                  average: i.averagePerDay,
                  semanticLabel:
                      'Daily spending in ${monthName(i.month.month)}, '
                      'average ${formatMoney(i.averagePerDay, appCurrency, round: true)} a day',
                  labelFor: (d) =>
                      '${d + 1} ${DateFormat('MMM').format(i.month.month)} · '
                      '${formatMoney(i.daily[d], appCurrency, round: true)}',
                  axisLabels: {0: '1', 9: '10', 19: '20', i.daily.length - 1: '${i.daily.length}'},
                ),
              ),
              const SectionHeader('Last 6 months'),
              SurfaceCard(
                child: BarChart(
                  height: 120,
                  values: [for (final m in i.trend) m.spentMinor],
                  highlight: i.trend.length - 1,
                  semanticLabel: 'Monthly spending for the last six months',
                  labelFor: (k) =>
                      '${monthLabel(i.trend[k].month)} · '
                      '${formatMoney(i.trend[k].spentMinor, appCurrency, round: true)}',
                  axisLabels: {for (final (k, m) in i.trend.indexed) k: DateFormat('MMM').format(m.month)},
                ),
              ),
              if (i.changes.isNotEmpty) ...[
                SectionHeader('vs ${DateFormat('MMMM').format(i.trend[4].month)}'),
                _Changes(changes: i.changes),
              ],
              if (i.topPayees.isNotEmpty) ...[const SectionHeader('Top payees'), _TopPayees(payees: i.topPayees)],
              if (app.recurring.isNotEmpty) ...[
                const SectionHeader('Repeating payments'),
                _Recurring(items: app.recurring),
              ],
              if (i.biggest.isNotEmpty) ...[
                SectionHeader(
                  'Biggest payments',
                  trailing: TextButton(onPressed: () => AppShell.switchTo(context, AppShell.activity), child: const Text('All')),
                ),
                TxnDayList(items: i.biggest, currency: appCurrency, grouped: false),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _Pace extends StatelessWidget {
  const _Pace({required this.insights, required this.current});

  final Insights insights;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final i = insights;
    final spent = i.month.spentMinor;
    final before = i.lastMonthToDate;
    final pct = before == 0 ? null : ((spent - before) / before * 100).round();
    final up = spent > before;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  label: current ? 'So far' : 'Spent',
                  value: formatCompact(spent),
                  // ₹, not %: "↑282%" says little when last month was quiet.
                  caption: before == 0
                      ? 'nothing last month'
                      : 'vs ${formatCompact(before)} ${current ? 'by now ' : ''}last month',
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: StatTile(
                  label: i.projectedMinor != null ? 'On track for' : 'Per day',
                  value: formatCompact(i.projectedMinor ?? i.averagePerDay),
                  caption: i.projectedMinor != null
                      ? 'at ${formatCompact(i.averagePerDay)} a day'
                      : 'over ${i.dayOfMonth} days',
                ),
              ),
            ],
          ),
        ),
        if (pct != null && pct.abs() >= 10) ...[
          const SizedBox(height: Space.md),
          Tray(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            radius: Radii.tile,
            child: Row(
              children: [
                Icon(up ? Icons.trending_up : Icons.trending_down, color: up ? t.accent : t.success),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    up
                        ? "You're spending ${formatCompact(spent - before)} more than this time last month."
                        : "You're ${formatCompact(before - spent)} under where you were last month.",
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Changes extends StatelessWidget {
  const _Changes({required this.changes});

  final List<CategoryChange> changes;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      child: Column(
        children: [
          for (final (k, c) in changes.indexed) ...[
            if (k > 0) Divider(height: 1, color: t.tray),
            InkWell(
              onTap: () => push(context, TransactionsScreen.category(c.category)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Row(
                  children: [
                    Icon(c.category.icon, size: 20, color: t.muted),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.category.label, style: text.bodyMedium),
                          Text(
                            '${formatCompact(c.lastMonth)} → ${formatCompact(c.thisMonth)}',
                            style: text.bodySmall?.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      c.delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: c.delta > 0 ? t.accent : t.success,
                    ),
                    const SizedBox(width: Space.xs),
                    Text(formatCompact(c.delta.abs()), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopPayees extends StatelessWidget {
  const _TopPayees({required this.payees});

  final List<PayeeTotal> payees;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      child: Column(
        children: [
          for (final (k, p) in payees.indexed) ...[
            if (k > 0) Divider(height: 1, color: t.tray),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Avatar(p.payee),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text(
                          '${p.count} payment${p.count == 1 ? '' : 's'}',
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(p.amountMinor, appCurrency, round: true),
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Recurring extends StatelessWidget {
  const _Recurring({required this.items});

  final List<Recurring> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final monthly = items.fold(0, (sum, r) => sum + r.monthlyMinor);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatMoney(monthly, appCurrency, round: true)} a month across ${items.length}',
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
          for (final r in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                    child: Icon(r.category.icon, size: 20, color: t.ink),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text(
                          '${r.cadence.label} · next ${DateFormat('d MMM').format(r.nextDue)}',
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(r.amountMinor, appCurrency),
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
