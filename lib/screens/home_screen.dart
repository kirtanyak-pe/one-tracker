import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../engine/recurring.dart';
import '../engine/summary.dart';
import '../money.dart';
import '../ui/access_disclosure.dart';
import '../ui/format.dart';
import '../ui/motion.dart';

import 'package:onyx/onyx.dart';

import 'activity_screen.dart';
import 'add_expense_screen.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'categories_screen.dart';
import 'widgets/month_nudge_card.dart';
import 'widgets/month_switcher.dart';
import 'widgets/review_card.dart';
import 'widgets/txn_list.dart';

void push(BuildContext context, Widget screen) => pushScreen(context, screen);

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final m = app.month;
    final review = app.toReview;
    final needsSetup = app.isAndroid && (!app.smsGranted || !app.notificationsGranted);
    final upcoming = app.isCurrentMonth ? app.upcoming() : const <Recurring>[];

    return OTabPage(
      title: 'One Tracker',
      glow: true,
      // Once the big number scrolls away, the bar keeps it in view.
      swapAfter: 64,
      scrolledTitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: formatMoney(m.spentMinor, appCurrency, round: true)),
            TextSpan(
              text: '  ${DateFormat('MMM').format(m.month)}',
              style: text.title3.copyWith(color: t.inkSoft),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.title2.tabular,
      ),
      actions: [
        if (app.scanning)
          Padding(
            padding: const EdgeInsets.only(right: OSpace.xs),
            child: OSpinner(size: 16, color: t.inkSoft),
          ),
        OIconButton(
          icon: LucideIcons.search,
          label: 'Search',
          filled: true,
          size: 44,
          onPressed: () {
            AppShell.switchTo(context, AppShell.activity);
            ActivityTab.focusSearch();
          },
        ),
        OIconButton(
          icon: LucideIcons.plus,
          label: 'Add expense',
          filled: true,
          size: 44,
          onPressed: () => push(context, const AddExpenseScreen()),
        ),
        OIconButton(
          icon: LucideIcons.slidersHorizontal,
          label: 'Settings',
          filled: true,
          size: 44,
          onPressed: () => push(context, const SettingsScreen()),
        ),
      ],
      body: ORefresh(
        onRefresh: () => app.scanSms(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xl, OSpace.gutter, navClearance),
          children: staggered([
            _Headline(app: app),
            const SizedBox(height: OSpace.xxl),
            if (app.monthNudge case final nudge?) ...[MonthNudgeCard(nudge: nudge), const SizedBox(height: OSpace.xl)],
            if (review.isNotEmpty) ...[
              ReviewCard(queue: review, currency: appCurrency),
              const SizedBox(height: OSpace.xl),
            ],
            if (needsSetup) ...[_SetupTray(app: app), const SizedBox(height: OSpace.xl)],
            const OSectionHeader('Recent', top: 0),
            if (m.items.isEmpty)
              _Empty(app: app)
            else ...[
              TxnDayList(items: m.items.take(6).toList(), currency: appCurrency),
              Center(
                child: OTextButton(
                  label: 'View all activity',
                  icon: LucideIcons.arrowRight,
                  onPressed: () => AppShell.switchTo(context, AppShell.activity),
                ),
              ),
            ],
            if (upcoming.isNotEmpty) ...[const OSectionHeader('Coming up'), _Upcoming(items: upcoming)],
            if (m.byCategory.isNotEmpty) ...[const SizedBox(height: OSpace.xxxl), _CategoriesLink(summary: m)],
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
    final t = context.colors;
    final text = context.type;
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
          Text(app.isCurrentMonth ? 'Spent this month' : 'Spent in ${monthName(m.month)}', style: text.small),
          const SizedBox(height: OSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedMoney(m.spentMinor, round: true, style: text.hero.tabular),
          ),
          if (change != null) ...[const SizedBox(height: OSpace.sm), _ChangeLine(change: change)],
          const SizedBox(height: OSpace.xl),
          const MonthSwitcher(),
          if (use != null && limit != null) ...[
            const SizedBox(height: OSpace.xl),
            Semantics(
              label: '${(use * 100).round()} percent of monthly budget used',
              child: AnimatedMeter(
                value: use,
                height: 6,
                background: t.lineStrong,
                // Meter colour carries severity: ink → accent at 80% → error over.
                color: use >= 1
                    ? t.negative
                    : use >= 0.8
                    ? t.accent
                    : t.ink,
              ),
            ),
            const SizedBox(height: OSpace.sm),
            Text(
              use >= 1
                  ? '${formatMoney(m.spentMinor - limit, appCurrency, round: true)} over your ${formatCompact(limit)} budget'
                  : '${formatMoney(limit - m.spentMinor, appCurrency, round: true)} left of ${formatCompact(limit)}',
              style: text.small.copyWith(color: t.inkSoft),
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

/// The move against last month under the big number, the way a portfolio
/// shows its day: ↗ ₹6,706 (12%). Up means spending more, so it's red and
/// down is green.
class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change});

  final _Change change;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final p = change.percent;
    final fg = p > 0
        ? t.negative
        : p < 0
        ? t.positive
        : t.inkSoft;
    final more = change.diffMinor >= 0;
    final amount = formatMoney(change.diffMinor.abs(), appCurrency, round: true);
    final percent = p.abs() > 999 ? '999+%' : '${p.abs()}%';
    return Semantics(
      label: '$amount ${more ? 'more' : 'less'} than ${change.against}',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              p > 0
                  ? LucideIcons.trendingUp
                  : p < 0
                  ? LucideIcons.trendingDown
                  : LucideIcons.minus,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: OSpace.xs + OSpace.xxs),
            Text('$amount ($percent)', style: text.bodyStrong.tabular.tint(fg)),
            Text('  vs ${change.against}', style: text.small),
          ],
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
    final t = context.colors;
    final text = context.type;
    final smsFirst = !app.smsGranted;
    return OInset(
      padding: const EdgeInsets.all(OSpace.xl),
      radius: ORadius.lg,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(smsFirst ? 'Read your bank SMS' : 'Catch payments instantly', style: text.title3),
                const SizedBox(height: OSpace.xs),
                Text(
                  smsFirst
                      ? 'Finds the last 90 days of spending. Nothing leaves your phone.'
                      : 'Notification access picks up UPI app payments as they happen.',
                  style: text.small.copyWith(color: t.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: OSpace.md),
          OIconButton(
            icon: smsFirst ? LucideIcons.messageSquareText : LucideIcons.bellRing,
            label: smsFirst ? 'Allow SMS access' : 'Allow notification access',
            size: 44,
            background: t.ink,
            color: t.onInk,
            onPressed: () => askAccess(context, smsFirst ? Access.sms : Access.notifications),
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
    final t = context.colors;
    final text = context.type;
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: OSpace.md),
        itemBuilder: (_, i) {
          final r = items[i];
          return SizedBox(
            width: 160,
            child: OCard(
              padding: const EdgeInsets.all(OSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(r.category.icon, size: 18, color: t.inkSoft),
                      const Spacer(),
                      Text(due(r.nextDue), style: text.small.copyWith(color: t.inkSoft)),
                    ],
                  ),
                  const Spacer(),
                  Text(r.payee, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.title3),
                  Text(
                    '${formatMoney(r.amountMinor, appCurrency)} · ${r.cadence.label.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(color: t.inkSoft),
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
    final t = context.colors;
    final text = context.type;
    final cats = summary.byCategory;
    final total = summary.spentMinor;
    final top = cats.take(3).toList();
    final rest = total - top.fold(0, (sum, c) => sum + c.amountMinor);
    // One hue, ranked: biggest in ink, the rest in fading ink.
    final shades = [t.ink, t.ink.withValues(alpha: 0.7), t.ink.withValues(alpha: 0.4), t.ink.withValues(alpha: 0.15)];
    final segments = [
      for (final (i, c) in top.indexed) (value: c.amountMinor, color: shades[i]),
      if (rest > 0) (value: rest, color: shades[3]),
    ];

    return OCard(
      onTap: () => push(context, const CategoriesScreen()),
      padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.lg, OSpace.md, OSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Where it went', style: text.title3)),
              Text('${cats.length} categories', style: text.small.copyWith(color: t.inkSoft)),
              Icon(LucideIcons.chevronRight, size: 20, color: t.inkSoft),
            ],
          ),
          const SizedBox(height: OSpace.md),
          Padding(
            padding: const EdgeInsets.only(right: OSpace.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ORadius.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  // Empty colour boxes need stretching, or they're 0px tall.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, seg) in segments.indexed) ...[
                      // 2px surface gap between segments.
                      if (i > 0) SizedBox(width: 2, child: ColoredBox(color: t.surface)),
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
          const SizedBox(height: OSpace.md),
          Wrap(
            spacing: OSpace.md,
            runSpacing: OSpace.xs,
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
                    const SizedBox(width: OSpace.xs),
                    Text(
                      '${c.category.label} ${formatCompact(c.amountMinor)}',
                      style: text.small.copyWith(color: t.inkSoft),
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
    final t = context.colors;
    final text = context.type;
    return OInset(
      padding: const EdgeInsets.all(OSpace.xl),
      radius: ORadius.lg,
      child: Column(
        children: [
          Icon(LucideIcons.receiptText, size: 36, color: t.inkSoft),
          const SizedBox(height: OSpace.md),
          Text('No transactions yet', style: text.title3),
          const SizedBox(height: OSpace.xs),
          Text(
            app.isAndroid
                ? 'Allow SMS access and your bank alerts will show up here.'
                : 'Tap Samples to see how it works with example bank SMS.',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
        ],
      ),
    );
  }
}
