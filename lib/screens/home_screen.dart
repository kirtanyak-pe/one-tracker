import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/recurring.dart';
import '../engine/summary.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'add_expense_screen.dart';
import 'budgets_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'categories_screen.dart';
import 'widgets/month_switcher.dart';
import 'widgets/review_card.dart';
import 'widgets/txn_list.dart';

void push(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _scan(BuildContext context) async {
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!app.isAndroid) {
      await app.loadSamples();
      messenger.showSnackBar(const SnackBar(content: Text('Loaded sample bank SMS')));
      return;
    }
    if (!app.smsGranted) return app.requestSms();
    final added = await app.scanSms(full: true);
    messenger.showSnackBar(SnackBar(
      content: Text(added == 0 ? 'All caught up' : 'Found $added new transaction${added == 1 ? '' : 's'}'),
    ));
  }

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
                  Expanded(child: Text('Auto Spend', style: text.titleMedium?.copyWith(color: t.muted))),
                  if (app.scanning)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.md),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
                      ),
                    ),
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
              if (review.isNotEmpty) ...[
                ReviewCard(queue: review, currency: appCurrency),
                const SizedBox(height: Space.xl),
              ],
              if (needsSetup) ...[
                _SetupTray(app: app),
                const SizedBox(height: Space.xl),
              ],
              Row(
                children: [
                  Expanded(
                    child: QuickAction(
                      icon: Icons.add,
                      label: 'Add',
                      onTap: () => push(context, const AddExpenseScreen()),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: QuickAction(
                      icon: app.isAndroid ? Icons.sms_outlined : Icons.science_outlined,
                      label: app.isAndroid ? 'Scan' : 'Samples',
                      highlight: app.isAndroid && !app.smsGranted,
                      onTap: () => _scan(context),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: QuickAction(
                      icon: Icons.donut_large_outlined,
                      label: 'Budgets',
                      onTap: () => push(context, const BudgetsScreen()),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: QuickAction(
                      icon: Icons.auto_fix_high_outlined,
                      label: 'Rules',
                      onTap: () => push(context, const RulesScreen()),
                    ),
                  ),
                ],
              ),
              SectionHeader(
                'Recent',
                trailing: m.items.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => AppShell.switchTo(context, 2),
                        child: const Text('See all'),
                      ),
              ),
              if (m.items.isEmpty)
                _Empty(app: app)
              else
                TxnDayList(items: m.items.take(6).toList(), currency: appCurrency),
              if (upcoming.isNotEmpty) ...[
                const SectionHeader('Coming up'),
                _Upcoming(items: upcoming),
              ],
              if (m.byCategory.isNotEmpty) ...[
                const SizedBox(height: Space.xxxl),
                _CategoriesLink(summary: m),
              ],
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
          child: AnimatedMoney(
            m.spentMinor,
            round: true,
            style: text.displaySmall?.copyWith(fontSize: 48),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          app.isCurrentMonth ? 'spent this month' : 'spent in ${monthName(m.month)}',
          style: text.bodyLarge?.copyWith(color: t.muted),
        ),
        if (use != null && limit != null) ...[
          const SizedBox(height: Space.lg),
          Semantics(
            label: '${(use * 100).round()} percent of monthly budget used',
            child: AnimatedMeter(
              value: use,
              height: 6,
              background: t.trayDeep,
              // Meter colour carries severity: ink → accent at 80% → error over.
              color: use >= 1 ? Theme.of(context).colorScheme.error : use >= 0.8 ? t.accent : t.ink,
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
          Text(
            [
              if (m.incomeMinor > 0) '${formatMoney(m.incomeMinor, appCurrency, round: true)} in',
              if (m.excludedMinor > 0) '${formatMoney(m.excludedMinor, appCurrency, round: true)} excluded',
            ].join('  ·  '),
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
        ],
      ],
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

/// One-line entry to the category breakdown (an L2 page).
class _CategoriesLink extends StatelessWidget {
  const _CategoriesLink({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final top = summary.byCategory.first;
    final n = summary.byCategory.length;
    return SurfaceCard(
      onTap: () => push(context, const CategoriesScreen()),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
            child: Icon(Icons.donut_small_outlined, size: 22, color: t.ink),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where it went', style: text.titleMedium),
                Text(
                  '${top.category.label} leads · $n categor${n == 1 ? 'y' : 'ies'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.muted),
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
