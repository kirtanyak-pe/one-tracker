import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../detection/detected_payment.dart';
import '../detection/payment_watcher.dart';
import '../history/split_record.dart';
import '../money.dart';
import '../overlay/quick_split_card.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import 'settings_screen.dart';
import 'split_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context).onBubbleFallback = _showQuickSplitSheet;
  }

  void _showQuickSplitSheet(DetectedPayment payment) {
    final app = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: QuickSplitCard(
            payment: payment,
            groups: app.groups,
            currency: app.currency,
            onSplit: (group) => app.splitWithGroup(
              group: group,
              amountMinor: payment.amountMinor,
              description: payment.merchant ?? 'Payment',
              from: payment,
            ),
            onLater: () => Navigator.pop(sheet),
            onMoreOptions: () {
              Navigator.pop(sheet);
              _openSplit(payment);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openSplit([DetectedPayment? payment]) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SplitScreen(payment: payment)),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Added to Splitwise')));
    }
  }

  void _openSettings() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final week = app.weekSummary;
    final needsSetup = app.isDemo ||
        (PaymentWatcher.isSupported && (!app.detectionGranted || !app.bubbleGranted));

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: app.refreshSplitwise,
            color: t.ink,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
              children: [
                _TopRow(app: app, onTap: _openSettings),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xxxl + Space.sm),
                  child: Text(
                    _headline(app.inbox.length),
                    textAlign: TextAlign.center,
                    style: text.displaySmall,
                  ),
                ),
                _StatusTray(app: app),
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    Expanded(
                      child: QuickAction(icon: Icons.add, label: 'Add', onTap: _openSplit),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.bolt,
                        label: 'Test',
                        onTap: app.simulatePayment,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.sync,
                        label: 'Sync',
                        onTap: app.refreshSplitwise,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: QuickAction(
                        icon: Icons.tune,
                        label: 'Settings',
                        highlight: needsSetup,
                        onTap: _openSettings,
                      ),
                    ),
                  ],
                ),
                const SectionHeader('This week'),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Waiting',
                        value: formatMoney(app.waitingMinor, app.currency),
                        caption: _count(app.inbox.length, 'payment'),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: StatTile(
                        label: 'Split',
                        value: formatMoney(week.totalMinor, app.currency),
                        caption: _count(week.count, 'split'),
                        trailing: RingProgress(value: week.share, size: 36, accent: true),
                      ),
                    ),
                  ],
                ),
                if (app.inbox.isNotEmpty) ...[
                  const SectionHeader('To split'),
                  for (final payment in app.inbox) ...[
                    _PaymentCard(
                      payment: payment,
                      currency: app.currency,
                      onSplit: () => _openSplit(payment),
                      onSkip: () => app.dismiss(payment),
                    ),
                    const SizedBox(height: Space.md),
                  ],
                ],
                if (app.history.isNotEmpty) ...[
                  const SectionHeader('Recent splits'),
                  _RecentSplits(records: app.history.take(4).toList(), currency: app.currency),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _headline(int waiting) => switch (waiting) {
        0 => "You're all\nsquare!",
        1 => '1 payment\nto split',
        _ => '$waiting payments\nto split',
      };

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.app, required this.onTap});

  final AppController app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final name = app.currentUser?.user.firstName;
    final live = !app.isDemo && app.error == null;
    return Row(
      children: [
        Expanded(
          child: Text(
            name == null || app.isDemo ? 'Auto Split' : 'Hi, $name',
            style: text.titleMedium?.copyWith(color: t.muted),
          ),
        ),
        Material(
          color: t.tray,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: live ? t.success : t.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(live ? 'Splitwise' : 'Demo', style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTray extends StatelessWidget {
  const _StatusTray({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final canDetect = PaymentWatcher.isSupported;
    final detectionOff = canDetect && !app.detectionGranted;

    final title = !canDetect
        ? 'Auto-detect runs on Android'
        : detectionOff
            ? 'Payment detection is off'
            : "I'm watching your payments";

    final String subtitle;
    if (app.loading) {
      subtitle = 'Connecting to Splitwise…';
    } else if (app.error != null) {
      subtitle = app.error!;
    } else if (app.isDemo) {
      subtitle = 'Using demo groups — connect Splitwise in Settings';
    } else {
      subtitle = 'Splits go to ${app.currentUser?.user.name ?? 'Splitwise'}';
    }

    return Tray(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: app.error != null ? Theme.of(context).colorScheme.error : t.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          AccentOrb(
            icon: detectionOff ? Icons.notifications_active_outlined : Icons.bolt,
            tooltip: detectionOff ? 'Turn on detection' : 'Try with a test payment',
            onPressed: detectionOff ? app.requestDetection : app.simulatePayment,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.currency,
    required this.onSplit,
    required this.onSkip,
  });

  final DetectedPayment payment;
  final String currency;
  final VoidCallback onSplit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(payment.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onSkip(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xxl),
        decoration: BoxDecoration(
          color: t.trayDeep,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Text('Skip', style: text.labelLarge),
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
        onTap: onSplit,
        child: Row(
          children: [
            Avatar(payment.merchant ?? '₹', size: 44),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.merchant ?? 'Payment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoney(payment.amountMinor, currency)} · ${friendlyTime(payment.detectedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton(
              onPressed: onSplit,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
              child: const Text('Split'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSplits extends StatelessWidget {
  const _RecentSplits({required this.records, required this.currency});

  final List<SplitRecord> records;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Tray(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      radius: Radii.tile,
      child: Column(
        children: [
          for (var i = 0; i < records.length; i++) ...[
            if (i > 0) Divider(height: 1, color: t.trayDeep),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 18, color: t.success),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(records[i].description, style: text.bodyMedium),
                        Text(
                          '${records[i].withWhom} · ${friendlyTime(records[i].at)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(records[i].amountMinor, currency),
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
