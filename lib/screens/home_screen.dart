import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../detection/detected_payment.dart';
import '../detection/payment_watcher.dart';
import '../money.dart';
import '../overlay/quick_split_card.dart';
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Split'),
        actions: [
          IconButton(
            tooltip: 'Simulate a payment',
            icon: const Icon(Icons.bolt),
            onPressed: app.simulatePayment,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSplit,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: RefreshIndicator(
        onRefresh: app.refreshSplitwise,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _StatusCard(app: app),
            const SizedBox(height: 24),
            Text('To split', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (app.inbox.isEmpty)
              _EmptyInbox(app: app)
            else
              for (final payment in app.inbox)
                _PaymentTile(
                  payment: payment,
                  currency: app.currency,
                  onSplit: () => _openSplit(payment),
                  onDismiss: () => app.dismiss(payment),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String splitwiseLine;
    if (app.loading) {
      splitwiseLine = 'Connecting to Splitwise…';
    } else if (app.error != null) {
      splitwiseLine = app.error!;
    } else if (app.isDemo) {
      splitwiseLine = 'Demo mode — add your Splitwise API key in Settings';
    } else {
      splitwiseLine = 'Connected as ${app.currentUser?.user.name}';
    }

    final detectionLine = !PaymentWatcher.isSupported
        ? 'Auto-detection works on Android only'
        : app.detectionGranted
            ? 'Watching bank & UPI notifications'
            : 'Payment detection is off';

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              icon: app.isDemo ? Icons.science_outlined : Icons.link,
              text: splitwiseLine,
              ok: !app.isDemo && app.error == null,
            ),
            const SizedBox(height: 12),
            _StatusRow(
              icon: Icons.notifications_active_outlined,
              text: detectionLine,
              ok: app.detectionGranted,
            ),
            if (PaymentWatcher.isSupported && !app.detectionGranted) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: app.requestDetection,
                child: const Text('Turn on detection'),
              ),
            ],
            if (app.isDemo && !app.loading) ...[
              const SizedBox(height: 4),
              Text(
                'Tap ⚡ to try the flow with a fake payment.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.text, required this.ok});

  final IconData icon;
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: ok ? colors.primary : colors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Nothing to split', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Pay with any UPI app or card and we\'ll ask if you want to split it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.currency,
    required this.onSplit,
    required this.onDismiss,
  });

  final DetectedPayment payment;
  final String currency;
  final VoidCallback onSplit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(payment.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Text('Skip'),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
          title: Text(payment.merchant ?? 'Payment'),
          subtitle: Text(DateFormat('d MMM, h:mm a').format(payment.detectedAt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatMoney(payment.amountMinor, currency)),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: onSplit, child: const Text('Split')),
            ],
          ),
        ),
      );
}
