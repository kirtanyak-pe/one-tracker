import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/recurring.dart';
import '../engine/summary.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'activity_screen.dart';
import 'add_expense_screen.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'categories_screen.dart';
import 'transactions_screen.dart';
import 'widgets/month_nudge_card.dart';
import 'widgets/month_switcher.dart';
import 'widgets/review_card.dart';
import 'widgets/txn_list.dart';

void push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = app.month;
    final review = app.toReview;
    final needsSetup = app.isAndroid && (!app.smsGranted || !app.notificationsGranted);
    final upcoming = app.isCurrentMonth ? app.upcoming() : const <Recurring>[];

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.ink,
          onRefresh: () => app.scanSms(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, navClearance),
            children: staggered([
              Row(
                children: [
                  Expanded(
                    child: Text('One Tracker', style: text.titleMedium?.copyWith(color: t.muted)),
                  ),
                  if (app.scanning)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.md),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
                      ),
                    ),
                  CircleIconButton(
                    icon: Icons.search,
                    tooltip: 'Search',
                    onPressed: () {
                      AppShell.switchTo(context, AppShell.activity);
                      ActivityTab.focusSearch();
                    },
                  ),
                  const SizedBox(width: Space.sm),
                  CircleIconButton(
                    icon: Icons.add,
                    tooltip: 'Add expense',
                    onPressed: () => push(context, const AddExpenseScreen()),
                  ),
                  const SizedBox(width: Space.sm),
                  CircleIconButton(
                    icon: Icons.tune,
                    tooltip: 'Settings',
                    onPressed: () => push(context, const SettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              _Headline(app: app),
              const SizedBox(height: Space.xxl),
              if (app.monthNudge case final nudge?) ...[MonthNudgeCard(nudge: nudge), const SizedBox(height: Space.xl)],
              if (review.isNotEmpty) ...[
                ReviewCard(queue: review, currency: appCurrency),
                const SizedBox(height: Space.xl),
              ],
              if (needsSetup) ...[_SetupTray(app: app), const SizedBox(height: Space.xl)],
              SectionHeader(
                'Recent',
                trailing: m.items.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => AppShell.switchTo(context, AppShell.activity),
                        child: const Text('See all'),
                      ),
              ),
              if (m.items.isEmpty)
                _Empty(app: app)
              else
                TxnDayList(items: m.items.take(6).toList(), currency: appCurrency),
              if (upcoming.isNotEmpty) ...[const SectionHeader('Coming up'), _Upcoming(items: upcoming)],
              if (m.byCategory.isNotEmpty) ...[const SizedBox(height: Space.xxxl), _CategoriesLink(summary: m)],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = app.month;
    final use = app.budgetUse;
    final limit = app.budgets.monthlyMinor;

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedMoney(m.spentMinor, round: true, style: text.displaySmall?.copyWith(fontSize: 48)),
        ),
        const SizedBox(height: Space.xs),
        Text(
          app.isCurrentMonth ? 'spent this month' : 'spent in ${monthName(m.month)}',
          style: text.bodyLarge?.copyWith(color: t.muted),
        ),
        if (_context(app) case final c?) ...[const SizedBox(height: Space.sm), _ContextPill(parts: c)],
        if (use != null && limit != null) ...[
          const SizedBox(height: Space.lg),
          Semantics(
            label: '${(use * 100).round()} percent of monthly budget used',
            child: AnimatedMeter(
              value: use,
              height: 6,
              background: t.trayDeep,
              // Meter colour carries severity: ink → accent at 80% → error over.
              color: use >= 1
                  ? Theme.of(context).colorScheme.error
                  : use >= 0.8
                  ? t.accent
                  : t.ink,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            use >= 1
                ? '${formatMoney(m.spentMinor - limit, appCurrency, round: true)} over your ${formatCompact(limit)} budget'
                : '${formatMoney(limit - m.spentMinor, appCurrency, round: true)} left of ${formatCompact(limit)}',
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
        ],
        const SizedBox(height: Space.lg),
        const MonthSwitcher(),
        if (m.excludedMinor > 0 || m.incomeMinor > 0) ...[
          const SizedBox(height: Space.md),
          // Tappable: these were a cryptic line before.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (m.incomeMinor > 0)
                _MiniChip(
                  icon: Icons.south_west,
                  label: '${formatCompact(m.incomeMinor)} income',
                  onTap: () => push(context, const TransactionsScreen.income()),
                ),
              if (m.excludedMinor > 0)
                _MiniChip(
                  icon: Icons.swap_horiz,
                  label: '${formatCompact(m.excludedMinor)} not counted',
                  onTap: () => push(context, const TransactionsScreen.excluded()),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// "₹1,240 today · ↓ 12% vs Sep" for the current month; null otherwise or
  /// when there's nothing useful to say.
  static List<({IconData? icon, String text})>? _context(AppController app) {
    if (!app.isCurrentMonth) return null;
    final now = DateTime.now();
    final today = app.month.items
        .where((e) => e.countsAsSpend && DateUtils.isSameDay(e.txn.at, now))
        .fold(0, (sum, e) => sum + e.txn.amountMinor);
    final before = app.insights.lastMonthToDate;
    final spent = app.month.spentMinor;
    final parts = <({IconData? icon, String text})>[
      (icon: null, text: today == 0 ? 'Nothing spent today' : '${formatCompact(today)} today'),
    ];
    // Only compare when last month had real spending by now.
    // ₹ rather than %: "↑282%" alarms more than it informs.
    if (before >= 100000 && spent > 0) {
      final diff = spent - before;
      final prev = monthName(DateTime(now.year, now.month - 1)).substring(0, 3);
      if (diff.abs() * 20 >= before) {
        parts.add((
          icon: diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          text: '${formatCompact(diff.abs())} vs $prev',
        ));
      } else {
        parts.add((icon: null, text: 'about the same as $prev'));
      }
    }
    return parts;
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.parts});

  final List<({IconData? icon, String text})> parts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.ink, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
      decoration: BoxDecoration(color: t.tray, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, p) in parts.indexed) ...[
            if (i > 0) Text('  ·  ', style: text?.copyWith(color: t.muted)),
            if (p.icon != null) ...[
              // Up = spending more: accent; down: success. Text stays ink.
              Icon(p.icon, size: 14, color: p.icon == Icons.arrow_upward ? t.accent : t.success),
              const SizedBox(width: 2),
            ],
            Text(p.text, style: text),
          ],
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: t.trayDeep)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: t.muted),
                const SizedBox(width: Space.xs),
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.ink)),
                Icon(Icons.chevron_right, size: 16, color: t.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupTray extends StatelessWidget {
  const _SetupTray({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final smsFirst = !app.smsGranted;
    return Tray(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(smsFirst ? 'Read your bank SMS' : 'Catch payments instantly', style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  smsFirst
                      ? 'Finds the last 90 days of spending. Nothing leaves your phone.'
                      : 'Notification access picks up UPI app payments as they happen.',
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          AccentOrb(
            icon: smsFirst ? Icons.sms_outlined : Icons.notifications_active_outlined,
            tooltip: smsFirst ? 'Allow SMS access' : 'Allow notification access',
            onPressed: smsFirst ? app.requestSms : app.requestNotifications,
          ),
        ],
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.items});

  final List<Recurring> items;

  static String due(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return 'Due';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
        itemBuilder: (_, i) {
          final r = items[i];
          return SizedBox(
            width: 160,
            child: SurfaceCard(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(r.category.icon, size: 18, color: t.muted),
                      const Spacer(),
                      Text(due(r.nextDue), style: text.bodySmall?.copyWith(color: t.muted)),
                    ],
                  ),
                  const Spacer(),
                  Text(r.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                  Text(
                    '${formatMoney(r.amountMinor, appCurrency)} · ${r.cadence.label.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Entry to the category breakdown (an L2 page): the spending mix at a
/// glance — top categories as one segmented bar with a short legend.
class _CategoriesLink extends StatelessWidget {
  const _CategoriesLink({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final cats = summary.byCategory;
    final total = summary.spentMinor;
    final top = cats.take(3).toList();
    final rest = total - top.fold(0, (sum, c) => sum + c.amountMinor);
    // One hue, ranked: biggest in the accent, the rest in fading ink.
    final shades = [t.accent, t.ink, t.ink.withValues(alpha: 0.55), t.ink.withValues(alpha: 0.25)];
    final segments = [
      for (final (i, c) in top.indexed) (value: c.amountMinor, color: shades[i]),
      if (rest > 0) (value: rest, color: shades[3]),
    ];

    return SurfaceCard(
      onTap: () => push(context, const CategoriesScreen()),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Where it went', style: text.titleMedium)),
              Text('${cats.length} categories', style: text.bodySmall?.copyWith(color: t.muted)),
              Icon(Icons.chevron_right, color: t.muted),
            ],
          ),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  // Empty colour boxes need stretching, or they're 0px tall.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, seg) in segments.indexed) ...[
                      // 2px surface gap between segments.
                      if (i > 0) SizedBox(width: 2, child: ColoredBox(color: t.card)),
                      Expanded(
                        flex: (seg.value / total * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: seg.color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              for (final (i, c) in top.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: shades[i], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(
                      '${c.category.label} ${formatCompact(c.amountMinor)}',
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Tray(
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: t.muted),
          const SizedBox(height: Space.md),
          Text('No transactions yet', style: text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            app.isAndroid
                ? 'Allow SMS access and your bank alerts will show up here.'
                : 'Tap Samples to see how it works with example bank SMS.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}
