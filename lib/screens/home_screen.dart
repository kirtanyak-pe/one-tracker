import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/summary.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import 'add_expense_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'widgets/review_card.dart';
import 'widgets/txn_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

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

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: t.ink,
            onRefresh: () => app.scanSms(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Auto Spend', style: text.titleMedium?.copyWith(color: t.muted)),
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
                      icon: Icons.tune,
                      tooltip: 'Settings',
                      onPressed: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
                _MonthHeadline(app: app),
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
                        onTap: () => _push(context, const AddExpenseScreen()),
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
                        icon: Icons.swap_horiz,
                        label: 'Excluded',
                        onTap: () => _push(context, const TransactionsScreen.excluded()),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.south_west,
                        label: 'Income',
                        onTap: () => _push(context, const TransactionsScreen.income()),
                      ),
                    ),
                  ],
                ),
                if (m.byCategory.isNotEmpty) ...[
                  const SectionHeader('Where it went'),
                  _CategoryBreakdown(summary: m),
                ],
                const SectionHeader('Transactions', top: Space.xxxl),
                if (m.items.isEmpty)
                  _Empty(app: app)
                else
                  TxnDayList(items: m.items, currency: appCurrency),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeadline extends StatelessWidget {
  const _MonthHeadline({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = app.month;
    return Column(
      children: [
        Text(
          formatMoney(m.spentMinor, appCurrency),
          textAlign: TextAlign.center,
          style: text.displaySmall?.copyWith(fontSize: 44),
        ),
        const SizedBox(height: Space.xs),
        Text(
          app.isCurrentMonth ? 'spent this month' : 'spent in ${monthName(m.month)}',
          style: text.bodyLarge?.copyWith(color: t.muted),
        ),
        const SizedBox(height: Space.lg),
        Container(
          decoration: BoxDecoration(color: t.tray, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => app.shiftMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              SizedBox(
                width: 132,
                child: Text(monthLabel(m.month), textAlign: TextAlign.center, style: text.labelLarge),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: app.isCurrentMonth ? null : () => app.shiftMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (m.excludedMinor > 0 || m.incomeMinor > 0) ...[
          const SizedBox(height: Space.md),
          Text(
            [
              if (m.incomeMinor > 0) '${formatMoney(m.incomeMinor, appCurrency)} in',
              if (m.excludedMinor > 0) '${formatMoney(m.excludedMinor, appCurrency)} excluded',
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
                Text(
                  smsFirst ? 'Read your bank SMS' : 'Catch payments instantly',
                  style: text.titleMedium,
                ),
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

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final top = summary.byCategory.first.amountMinor;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        children: [
          for (final (i, c) in summary.byCategory.indexed)
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TransactionsScreen.category(c.category)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                      child: Icon(c.category.icon, size: 20, color: t.ink),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(c.category.label, style: text.bodyMedium)),
                              Text(
                                formatMoney(c.amountMinor, appCurrency),
                                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: LinearProgressIndicator(
                              value: c.amountMinor / top,
                              minHeight: 4,
                              backgroundColor: t.tray,
                              // Only the biggest category gets the accent.
                              color: i == 0 ? t.accent : t.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
