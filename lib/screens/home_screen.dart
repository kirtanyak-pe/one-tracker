import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    return TabPage(
      title: 'One Tracker',
      // Once the big number scrolls away, the bar keeps it in view.
      swapAfter: 64,
      scrolledTitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: formatMoney(m.spentMinor, appCurrency, round: true)),
            TextSpan(
              text: '  ${DateFormat('MMM').format(m.month)}',
              style: text.titleMedium?.copyWith(color: t.muted),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      actions: [
        if (app.scanning)
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.muted)),
          ),
        CircleIconButton(
          icon: Icons.search,
          tooltip: 'Search',
          onPressed: () {
            AppShell.switchTo(context, AppShell.activity);
            ActivityTab.focusSearch();
          },
        ),
        CircleIconButton(
          icon: Icons.add,
          tooltip: 'Add expense',
          onPressed: () => push(context, const AddExpenseScreen()),
        ),
        CircleIconButton(icon: Icons.tune, tooltip: 'Settings', onPressed: () => push(context, const SettingsScreen())),
      ],
      body: RefreshIndicator(
        color: t.ink,
        onRefresh: () => app.scanSms(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, navClearance),
          children: staggered([
            _Headline(app: app),
            const SizedBox(height: Space.xxl),
            if (app.monthNudge case final nudge?) ...[MonthNudgeCard(nudge: nudge), const SizedBox(height: Space.xl)],
            if (review.isNotEmpty) ...[
              ReviewCard(queue: review, currency: appCurrency),
              const SizedBox(height: Space.xl),
            ],
            if (needsSetup) ...[_SetupTray(app: app), const SizedBox(height: Space.xl)],
            const SectionHeader('Recent', top: 0),
            if (m.items.isEmpty)
              _Empty(app: app)
            else ...[
              TxnDayList(items: m.items.take(6).toList(), currency: appCurrency),
              Center(
                child: TextButton.icon(
                  onPressed: () => AppShell.switchTo(context, AppShell.activity),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View all activity'),
                ),
              ),
            ],
            if (upcoming.isNotEmpty) ...[const SectionHeader('Coming up'), _Upcoming(items: upcoming)],
            if (m.byCategory.isNotEmpty) ...[const SizedBox(height: Space.xxxl), _CategoriesLink(summary: m)],
          ]),
        ),
      ),
    );
  }
}

/// The one number that matters — spent in the month on screen — with how it
/// moved against last month beside it, and the month itself underneath.
/// Swipe sideways on it to change month.
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
    final change = _change(app);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 300) app.shiftMonth(-1);
        if (v < -300 && !app.isCurrentMonth) app.shiftMonth(1);
      },
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedMoney(m.spentMinor, round: true, style: text.displaySmall?.copyWith(fontSize: 56)),
                if (change != null) ...[const SizedBox(width: Space.sm), _ChangePill(change: change)],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          const MonthSwitcher(),
          if (use != null && limit != null) ...[
            const SizedBox(height: Space.xl),
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
        ],
      ),
    );
  }

  /// Against last month up to the same day (the whole of last month when
  /// looking back); null without real spending to compare to.
  static _Change? _change(AppController app) {
    final before = app.insights.lastMonthToDate;
    final spent = app.month.spentMinor;
    if (before < 100000 || spent == 0) return null;
    final prev = monthName(DateTime(app.month.month.year, app.month.month.month - 1));
    return (
      percent: ((spent - before) / before * 100).round(),
      diffMinor: spent - before,
      against: app.isCurrentMonth ? 'this point in $prev' : prev,
    );
  }
}

typedef _Change = ({int percent, int diffMinor, String against});

/// ▲ 12% the way a stock quote shows it, except up means spending more, so
/// it's red and down is green. Tap for the amount behind the percentage.
class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.change});

  final _Change change;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = change.percent;
    // Not the accent: it follows the wallpaper, so it can't mean "more".
    final fg = p > 0
        ? Theme.of(context).colorScheme.error
        : p < 0
        ? t.success
        : t.muted;
    final more = change.diffMinor >= 0;
    final detail =
        '${formatMoney(change.diffMinor.abs(), appCurrency, round: true)} ${more ? 'more' : 'less'} than ${change.against}';
    return Tooltip(
      message: detail,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: detail,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: dark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p > 0
                    ? Icons.arrow_drop_up
                    : p < 0
                    ? Icons.arrow_drop_down
                    : Icons.remove,
                size: 18,
                color: fg,
              ),
              Text(
                p.abs() > 999 ? '999+%' : '${p.abs()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
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
